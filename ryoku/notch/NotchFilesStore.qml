pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Manages Files hub operations for the Dynamic Notch:
// Shelf persistence, inline directory browsing, native picker fallback,
// smart format-aware Compress & Convert, Extract, Copy/Move, GDrive (rclone),
// Open With handlers, and Trash/Delete.
Singleton {
    id: fs

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    readonly property string homeDir: Quickshell.env("HOME") || "/tmp"

    property string activeTool: ""           // "" | "shelf" | "compress" | "convert" | "extract" | "copy" | "move" | "gdrive" | "openwith" | "delete"
    property var shelfFiles: []              // [{ path, name, ext, category, sizeText, isDir, addedMs }]
    property var selectedPaths: []           // subset (or all) active target paths for operations
    property string currentDir: homeDir
    property var dirEntries: []              // [{ path, name, ext, category, sizeText, isDir }]
    property bool busy: false
    property string statusMsg: ""
    property bool statusError: false

    // GDrive state via rclone
    property bool rcloneInstalled: false
    property bool rcloneChecking: false
    property string gdriveRemote: ""         // e.g. "gdrive:"
    property string gdriveSubdir: ""
    property var gdriveEntries: []           // [{ name, path, isDir, sizeText }]

    readonly property int selectedCount: fs.selectedPaths.length

    function extOf(p) {
        var base = String(p || "").split("/").pop() || "";
        var dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(dot + 1).toLowerCase() : "";
    }

    function nameOf(p) {
        var s = String(p || "").replace(/\/+$/, "");
        var idx = s.lastIndexOf("/");
        return idx >= 0 ? s.slice(idx + 1) : s;
    }

    function categoryForExt(ext, isDir) {
        if (isDir) return "folder";
        if (["png", "jpg", "jpeg", "webp", "avif", "gif", "bmp", "svg"].indexOf(ext) >= 0) return "image";
        if (["mp4", "mkv", "mov", "webm", "avi", "m4v"].indexOf(ext) >= 0) return "video";
        if (["mp3", "wav", "flac", "ogg", "m4a", "opus", "aac"].indexOf(ext) >= 0) return "audio";
        if (["zip", "tar", "gz", "tgz", "xz", "zst", "bz2", "7z", "rar", "iso"].indexOf(ext) >= 0) return "archive";
        if (["pdf", "doc", "docx", "odt", "xls", "xlsx", "ods", "ppt", "pptx", "odp", "txt", "md", "csv", "html", "json"].indexOf(ext) >= 0) return "document";
        return "other";
    }

    // Overall category across selected paths ("image" | "video" | "audio" | "document" | "archive" | "folder" | "mixed" | "none")
    readonly property string selectionCategory: {
        if (!fs.selectedPaths || fs.selectedPaths.length === 0) return "none";
        var cats = {};
        for (var i = 0; i < fs.selectedPaths.length; i++) {
            var p = fs.selectedPaths[i];
            var meta = fs.findMeta(p);
            var cat = meta ? meta.category : fs.categoryForExt(fs.extOf(p), false);
            cats[cat] = true;
        }
        var keys = Object.keys(cats);
        return keys.length === 1 ? keys[0] : "mixed";
    }

    readonly property bool archiveSelected: {
        if (fs.selectedPaths.length === 0) return false;
        for (var i = 0; i < fs.selectedPaths.length; i++) {
            var p = String(fs.selectedPaths[i]).toLowerCase();
            if (/\.(zip|tar\.gz|tgz|tar\.xz|tar\.zst|tar\.bz2|tar|7z|rar|iso)$/.test(p))
                return true;
        }
        return false;
    }

    function findMeta(path) {
        for (var i = 0; i < fs.shelfFiles.length; i++)
            if (fs.shelfFiles[i].path === path) return fs.shelfFiles[i];
        for (var j = 0; j < fs.dirEntries.length; j++)
            if (fs.dirEntries[j].path === path) return fs.dirEntries[j];
        return null;
    }

    function iconForCategory(cat) {
        if (cat === "folder") return "folder";
        if (cat === "image") return "image";
        if (cat === "video") return "movie";
        if (cat === "audio") return "audio_file";
        if (cat === "archive") return "folder_zip";
        if (cat === "document") return "description";
        return "draft";
    }

    function setMessage(msg, isErr) {
        fs.statusMsg = msg;
        fs.statusError = !!isErr;
    }

    function isSelected(path) {
        return fs.selectedPaths.indexOf(path) >= 0;
    }

    function toggleSelectPath(path) {
        var next = fs.selectedPaths.slice();
        var idx = next.indexOf(path);
        if (idx >= 0) next.splice(idx, 1);
        else next.push(path);
        fs.selectedPaths = next;
    }

    function setSingleSelected(path) {
        fs.selectedPaths = path ? [path] : [];
    }

    function addPathsToShelf(paths) {
        if (!paths || paths.length === 0) return;
        statRunner.pendingTargets = paths.slice();
        statRunner.actionAfterStat = "shelf";
        statRunner.runNext();
    }

    function addUrlsToShelf(urls) {
        if (!urls || urls.length === 0) return;
        var out = [];
        for (var i = 0; i < urls.length; i++) {
            var s = decodeURIComponent(String(urls[i] || "").trim()).replace(/^file:\/\//, "");
            if (s.indexOf("/") === 0) out.push(s);
        }
        if (out.length > 0) {
            fs.addPathsToShelf(out);
            fs.selectedPaths = out.slice();
        }
    }

    function removeFromShelf(path) {
        fs.shelfFiles = fs.shelfFiles.filter(function(item) { return item && item.path !== path; });
        fs.selectedPaths = fs.selectedPaths.filter(function(p) { return p !== path; });
        fs.persist();
    }

    function clearShelf() {
        fs.shelfFiles = [];
        fs.selectedPaths = [];
        fs.persist();
    }

    function openTool(toolId) {
        fs.statusMsg = "";
        fs.statusError = false;
        fs.activeTool = toolId;
        if (toolId === "gdrive")
            fs.checkRclone();
    }

    function browse(dirPath) {
        var target = (dirPath && dirPath !== "") ? dirPath : fs.homeDir;
        if (target.indexOf("~") === 0) target = fs.homeDir + target.slice(1);
        fs.currentDir = target;
        dirRunner.command = [
            "python3", "-c",
            "import os, json, sys\n" +
            "root = sys.argv[1]\n" +
            "def fmt(sz):\n" +
            "  for u in ('B','KB','MB','GB'):\n" +
            "    if sz < 1024 or u == 'GB': return f'{sz:.0f} {u}' if u=='B' else f'{sz:.1f} {u}'\n" +
            "    sz /= 1024.0\n" +
            "items = []\n" +
            "try:\n" +
            "  with os.scandir(root) as it:\n" +
            "    for e in it:\n" +
            "      if e.name.startswith('.'): continue\n" +
            "      is_d = e.is_dir(follow_symlinks=True)\n" +
            "      sz = 0 if is_d else e.stat(follow_symlinks=True).st_size\n" +
            "      items.append((0 if is_d else 1, e.name.lower(), e.name, e.path, is_d, fmt(sz)))\n" +
            "except Exception as ex:\n" +
            "  print(json.dumps({'error': str(ex), 'entries': []})); sys.exit(0)\n" +
            "items.sort(key=lambda x: (x[0], x[1]))\n" +
            "print(json.dumps({'entries': [{'name': x[2], 'path': x[3], 'isDir': x[4], 'sizeText': 'Folder' if x[4] else x[5]} for x in items[:80]]}))",
            target
        ];
        dirRunner.running = true;
    }

    function pickNativeFile(dirOnly) {
        if (pickerRunner.running) return;
        pickerRunner.command = [
            "sh", "-c",
            dirOnly
                ? "if command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$1\"; elif command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory --filename=\"$1/\"; fi"
                : "if command -v kdialog >/dev/null 2>&1; then kdialog --getopenfilename \"$1\"; elif command -v zenity >/dev/null 2>&1; then zenity --file-selection --multiple --separator='\n' --filename=\"$1/\"; fi",
            "sh", fs.currentDir
        ];
        pickerRunner.isDirPicker = !!dirOnly;
        pickerRunner.running = true;
    }

    function pastePathFromClipboard(rawText) {
        var lines = String(rawText || "").split(/\r?\n/);
        var valid = [];
        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].trim().replace(/^file:\/\//, "");
            if (s.indexOf("~/") === 0) s = fs.homeDir + s.slice(1);
            if (s.indexOf("/") === 0) valid.push(s);
        }
        if (valid.length === 0) {
            fs.setMessage("Clipboard has no valid file path (/... or ~/...)", true);
            return;
        }
        fs.addPathsToShelf(valid);
        fs.selectedPaths = valid.slice();
    }

    // ── Operations ───────────────────────────────────────────────────────────

    function runCompress(format, qualityPct) {
        if (fs.busy || fs.selectedPaths.length === 0) return;
        var targets = fs.selectedPaths.slice();
        fs.busy = true;
        fs.setMessage("Compressing...", false);

        var py =
            "import os, sys, shutil, subprocess\n" +
            "fmt = sys.argv[1]; qual = sys.argv[2]; paths = [p for p in sys.argv[3:] if os.path.exists(p)]\n" +
            "if not paths: print('No valid paths'); sys.exit(1)\n" +
            "parent = os.path.dirname(os.path.abspath(paths[0])) or '.'\n" +
            "stem = os.path.basename(paths[0].rstrip('/')) if len(paths) == 1 else 'archive'\n" +
            "if fmt in ('zip', 'tar.gz', '7z'):\n" +
            "  out = os.path.join(parent, f'{stem}.{fmt}')\n" +
            "  n = 1\n" +
            "  while os.path.exists(out): out = os.path.join(parent, f'{stem}_{n}.{fmt}'); n += 1\n" +
            "  rels = [os.path.relpath(p, parent) for p in paths]\n" +
            "  if fmt == 'zip':\n" +
            "    subprocess.check_call(['zip', '-r', '-q', out] + rels, cwd=parent)\n" +
            "  elif fmt == 'tar.gz':\n" +
            "    subprocess.check_call(['tar', '-czf', out, '-C', parent] + rels)\n" +
            "  else:\n" +
            "    cmd = shutil.which('7z') or shutil.which('7zz') or 'bsdtar'\n" +
            "    if os.path.basename(cmd) == 'bsdtar': subprocess.check_call([cmd, '-a', '-cf', out, '-C', parent] + rels)\n" +
            "    else: subprocess.check_call([cmd, 'a', out] + rels, cwd=parent)\n" +
            "  print('Saved: ' + out)\n" +
            "elif fmt == 'img_opt':\n" +
            "  outs = []\n" +
            "  for p in paths:\n" +
            "    root, ext = os.path.splitext(p)\n" +
            "    out = f'{root}_q{qual}{ext}'\n" +
            "    subprocess.check_call(['magick', p, '-strip', '-quality', str(qual), out])\n" +
            "    outs.append(out)\n" +
            "  print('Optimized ' + str(len(outs)) + ' image(s): ' + os.path.basename(outs[0]))\n" +
            "elif fmt == 'pdf_opt':\n" +
            "  gs = shutil.which('gs')\n" +
            "  if not gs: print('ghostscript (gs) not installed; use ZIP or 7z archive'); sys.exit(1)\n" +
            "  outs = []\n" +
            "  for p in paths:\n" +
            "    root, _ = os.path.splitext(p)\n" +
            "    out = f'{root}_compressed.pdf'\n" +
            "    subprocess.check_call([gs, '-sDEVICE=pdfwrite', '-dCompatibilityLevel=1.4', '-dPDFSETTINGS=/ebook', '-dNOPAUSE', '-dQUIET', '-dBATCH', f'-sOutputFile={out}', p])\n" +
            "    outs.append(out)\n" +
            "  print('Compressed PDF: ' + os.path.basename(outs[0]))\n" +
            "elif fmt == 'video_opt':\n" +
            "  outs = []\n" +
            "  for p in paths:\n" +
            "    root, _ = os.path.splitext(p)\n" +
            "    out = f'{root}_compressed.mp4'\n" +
            "    subprocess.check_call(['ffmpeg', '-y', '-i', p, '-vcodec', 'libx264', '-crf', '28', '-preset', 'veryfast', out])\n" +
            "    outs.append(out)\n" +
            "  print('Compressed video: ' + os.path.basename(outs[0]))\n";

        opRunner.command = ["python3", "-c", py, String(format), String(qualityPct || 75)].concat(targets);
        opRunner.refreshAfter = true;
        opRunner.running = true;
    }

    function runConvert(targetExt) {
        if (fs.busy || fs.selectedPaths.length === 0) return;
        var targets = fs.selectedPaths.slice();
        fs.busy = true;
        fs.setMessage("Converting to ." + targetExt + "...", false);

        var py =
            "import os, sys, shutil, subprocess\n" +
            "ext = sys.argv[1].lower(); paths = [p for p in sys.argv[2:] if os.path.isfile(p)]\n" +
            "if not paths: print('Select file(s) first'); sys.exit(1)\n" +
            "imgs = {'png','jpg','jpeg','webp','avif','gif','bmp','tiff'}\n" +
            "media = {'mp4','mkv','webm','mov','avi','mp3','wav','flac','ogg','m4a'}\n" +
            "docs = {'pdf','docx','odt','txt','html','rtf','xlsx','pptx'}\n" +
            "done = []\n" +
            "for p in paths:\n" +
            "  stem, src_ext = os.path.splitext(p); src_ext = src_ext.lstrip('.').lower()\n" +
            "  out_dir = os.path.dirname(p) or '.'\n" +
            "  if (src_ext in imgs) and (ext in imgs or ext == 'pdf'):\n" +
            "    out = f'{stem}.{ext}'\n" +
            "    subprocess.check_call(['magick', p, out])\n" +
            "    done.append(out)\n" +
            "  elif (src_ext in media or src_ext in imgs) and ext in media:\n" +
            "    out = f'{stem}.{ext}'\n" +
            "    subprocess.check_call(['ffmpeg', '-y', '-i', p, out])\n" +
            "    done.append(out)\n" +
            "  elif ext in docs:\n" +
            "    lo = shutil.which('libreoffice') or shutil.which('soffice')\n" +
            "    if not lo: print('libreoffice not available for document convert'); sys.exit(1)\n" +
            "    subprocess.check_call([lo, '--headless', '--convert-to', ext, '--outdir', out_dir, p])\n" +
            "    done.append(f'{stem}.{ext}')\n" +
            "  else:\n" +
            "    print(f'Unsupported conversion: .{src_ext} -> .{ext}'); sys.exit(1)\n" +
            "print('Converted: ' + ', '.join(os.path.basename(x) for x in done))\n";

        opRunner.command = ["python3", "-c", py, String(targetExt)].concat(targets);
        opRunner.refreshAfter = true;
        opRunner.running = true;
    }

    function runExtract() {
        if (fs.busy || fs.selectedPaths.length === 0) return;
        var targets = fs.selectedPaths.slice();
        fs.busy = true;
        fs.setMessage("Extracting...", false);

        var py =
            "import os, sys, shutil, subprocess\n" +
            "paths = [p for p in sys.argv[1:] if os.path.isfile(p)]\n" +
            "if not paths: print('No archive file selected'); sys.exit(1)\n" +
            "outs = []\n" +
            "for p in paths:\n" +
            "  base = os.path.basename(p)\n" +
            "  stem = base\n" +
            "  for suf in ('.tar.gz','.tar.xz','.tar.zst','.tar.bz2','.tgz','.zip','.7z','.rar','.tar','.iso'):\n" +
            "    if base.lower().endswith(suf): stem = base[:-len(suf)]; break\n" +
            "  dest = os.path.join(os.path.dirname(p) or '.', stem)\n" +
            "  os.makedirs(dest, exist_ok=True)\n" +
            "  low = base.lower()\n" +
            "  if low.endswith('.zip') and shutil.which('unzip'):\n" +
            "    subprocess.check_call(['unzip', '-o', p, '-d', dest])\n" +
            "  elif (shutil.which('7z') or shutil.which('7zz')) and (low.endswith('.7z') or low.endswith('.rar')):\n" +
            "    cmd = shutil.which('7z') or shutil.which('7zz')\n" +
            "    subprocess.check_call([cmd, 'x', '-y', f'-o{dest}', p])\n" +
            "  else:\n" +
            "    subprocess.check_call(['bsdtar', '-xf', p, '-C', dest])\n" +
            "  outs.append(dest)\n" +
            "print('Extracted to: ' + outs[0])\n";

        opRunner.command = ["python3", "-c", py].concat(targets);
        opRunner.refreshAfter = true;
        opRunner.running = true;
    }

    function runTransfer(destDir, isMove) {
        if (fs.busy || fs.selectedPaths.length === 0) return;
        var dest = String(destDir || "").trim();
        if (dest === "") return;
        if (dest.indexOf("~/") === 0 || dest === "~") dest = fs.homeDir + dest.slice(1);
        var targets = fs.selectedPaths.slice();
        fs.busy = true;
        fs.setMessage((isMove ? "Moving" : "Copying") + " to " + dest + "...", false);

        var py =
            "import os, sys, shutil\n" +
            "mode = sys.argv[1]; dest = sys.argv[2]; paths = sys.argv[3:]\n" +
            "os.makedirs(dest, exist_ok=True)\n" +
            "new_paths = []\n" +
            "for p in paths:\n" +
            "  if not os.path.exists(p): continue\n" +
            "  target = os.path.join(dest, os.path.basename(p.rstrip('/')))\n" +
            "  if os.path.abspath(p) == os.path.abspath(target): new_paths.append(target); continue\n" +
            "  if mode == 'move': shutil.move(p, target)\n" +
            "  elif os.path.isdir(p): shutil.copytree(p, target, dirs_exist_ok=True)\n" +
            "  else: shutil.copy2(p, target)\n" +
            "  new_paths.append(target)\n" +
            "print(('Moved ' if mode=='move' else 'Copied ') + str(len(new_paths)) + ' item(s) to ' + dest)\n";

        opRunner.command = ["python3", "-c", py, isMove ? "move" : "copy", dest].concat(targets);
        opRunner.refreshAfter = true;
        opRunner.running = true;
    }

    function runOpenWith(appCmd, path) {
        var target = path || (fs.selectedPaths.length > 0 ? fs.selectedPaths[0] : "");
        if (!target) {
            fs.setMessage("Select a file first", true);
            return;
        }
        if (appCmd === "terminal") {
            Quickshell.execDetached(["kitty", "--directory", target.indexOf(".") >= 0 ? target.replace(/\/[^/]+$/, "") : target]);
            fs.setMessage("Opened terminal", false);
            return;
        }
        Quickshell.execDetached([appCmd, target]);
        fs.setMessage("Launched " + appCmd + " on " + fs.nameOf(target), false);
    }

    function runDelete(permanent) {
        if (fs.busy || fs.selectedPaths.length === 0) return;
        var targets = fs.selectedPaths.slice();
        fs.busy = true;
        fs.setMessage(permanent ? "Deleting permanently..." : "Moving to Trash...", false);

        var py =
            "import os, sys, shutil, subprocess\n" +
            "perm = sys.argv[1] == '1'; paths = sys.argv[2:]\n" +
            "count = 0\n" +
            "for p in paths:\n" +
            "  if not os.path.exists(p): continue\n" +
            "  if not perm and shutil.which('gio'):\n" +
            "    subprocess.check_call(['gio', 'trash', p])\n" +
            "  elif os.path.isdir(p): shutil.rmtree(p)\n" +
            "  else: os.remove(p)\n" +
            "  count += 1\n" +
            "print(('Deleted ' if perm else 'Trashed ') + str(count) + ' item(s)')\n";

        opRunner.command = ["python3", "-c", py, permanent ? "1" : "0"].concat(targets);
        opRunner.clearSelectedAfter = true;
        opRunner.refreshAfter = true;
        opRunner.running = true;
    }

    // ── Google Drive via rclone ──────────────────────────────────────────────

    function checkRclone() {
        if (fs.rcloneChecking) return;
        fs.rcloneChecking = true;
        rcloneCheck.running = true;
    }

    function connectGdrive() {
        fs.setMessage("Opening browser for Google Drive OAuth...", false);
        Quickshell.execDetached(["sh", "-c", "rclone config create gdrive drive && touch /tmp/tsukuyomi-gdrive-updated"]);
        gdrivePoll.restart();
    }

    function listGdrive(subdir) {
        if (!fs.gdriveRemote) return;
        var sub = subdir !== undefined ? subdir : fs.gdriveSubdir;
        fs.gdriveSubdir = sub;
        var spec = fs.gdriveRemote + sub;
        gdriveListRunner.command = ["rclone", "lsjson", "--max-depth", "1", spec];
        gdriveListRunner.running = true;
    }

    function uploadToGdrive() {
        if (fs.busy || !fs.gdriveRemote || fs.selectedPaths.length === 0) return;
        var targets = fs.selectedPaths.slice();
        fs.busy = true;
        fs.setMessage("Uploading to " + fs.gdriveRemote + "...", false);
        var py =
            "import os, sys, subprocess\n" +
            "rem = sys.argv[1]; sub = sys.argv[2]; paths = sys.argv[3:]\n" +
            "for p in paths:\n" +
            "  dest = rem + (sub.strip('/') + '/' if sub.strip('/') else '') + os.path.basename(p.rstrip('/'))\n" +
            "  subprocess.check_call(['rclone', 'copyto', p, dest])\n" +
            "print('Uploaded ' + str(len(paths)) + ' item(s) to Google Drive')\n";
        opRunner.command = ["python3", "-c", py, fs.gdriveRemote, fs.gdriveSubdir].concat(targets);
        opRunner.refreshGdriveAfter = true;
        opRunner.running = true;
    }

    function downloadFromGdrive(remoteItem) {
        if (fs.busy || !fs.gdriveRemote || !remoteItem) return;
        fs.busy = true;
        fs.setMessage("Downloading " + remoteItem.name + "...", false);
        var src = fs.gdriveRemote + remoteItem.path;
        var dst = fs.homeDir + "/Downloads/" + remoteItem.name;
        opRunner.command = ["sh", "-c", "rclone copyto \"$1\" \"$2\" && echo \"Saved: $2\"", "sh", src, dst];
        opRunner.refreshAfter = true;
        opRunner.running = true;
    }

    Timer {
        id: gdrivePoll
        interval: 2500
        repeat: true
        onTriggered: {
            fs.checkRclone();
            if (fs.gdriveRemote !== "") stop();
        }
    }

    // ── Runners & Storage ────────────────────────────────────────────────────

    Process {
        id: dirRunner
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text || "{}");
                    var arr = Array.isArray(parsed.entries) ? parsed.entries : [];
                    var out = [];
                    for (var i = 0; i < arr.length; i++) {
                        var it = arr[i];
                        var ext = it.isDir ? "" : fs.extOf(it.path);
                        out.push({
                            name: it.name,
                            path: it.path,
                            ext: ext,
                            category: fs.categoryForExt(ext, it.isDir),
                            sizeText: it.sizeText,
                            isDir: !!it.isDir
                        });
                    }
                    fs.dirEntries = out;
                } catch (e) {
                    fs.dirEntries = [];
                }
            }
        }
    }

    Process {
        id: pickerRunner
        property bool isDirPicker: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = String(text || "").trim();
                if (!out) return;
                var lines = out.split(/\r?\n/).map(function(s) { return s.trim(); }).filter(function(s) { return s !== ""; });
                if (lines.length === 0) return;
                if (pickerRunner.isDirPicker) {
                    fs.browse(lines[0]);
                } else {
                    fs.addPathsToShelf(lines);
                    fs.selectedPaths = lines.slice();
                }
            }
        }
    }

    Process {
        id: statRunner
        property var pendingTargets: []
        property string actionAfterStat: ""
        function runNext() {
            if (pendingTargets.length === 0) return;
            var batch = pendingTargets.slice();
            pendingTargets = [];
            command = [
                "python3", "-c",
                "import os, json, sys\n" +
                "def fmt(sz):\n" +
                "  for u in ('B','KB','MB','GB'):\n" +
                "    if sz < 1024 or u == 'GB': return f'{sz:.0f} {u}' if u=='B' else f'{sz:.1f} {u}'\n" +
                "    sz /= 1024.0\n" +
                "out = []\n" +
                "for p in sys.argv[1:]:\n" +
                "  if not os.path.exists(p): continue\n" +
                "  is_d = os.path.isdir(p)\n" +
                "  sz = 0 if is_d else os.path.getsize(p)\n" +
                "  out.append({'path': os.path.abspath(p), 'name': os.path.basename(p.rstrip('/')), 'isDir': is_d, 'sizeText': 'Folder' if is_d else fmt(sz)})\n" +
                "print(json.dumps(out))",
            ].concat(batch);
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text || "[]");
                    if (arr.length === 0) {
                        fs.setMessage("File path not found on disk", true);
                        return;
                    }
                    var next = fs.shelfFiles.slice();
                    var existing = {};
                    for (var i = 0; i < next.length; i++) existing[next[i].path] = true;
                    for (var j = 0; j < arr.length; j++) {
                        var it = arr[j];
                        var ext = it.isDir ? "" : fs.extOf(it.path);
                        var rec = {
                            path: it.path,
                            name: it.name,
                            ext: ext,
                            category: fs.categoryForExt(ext, it.isDir),
                            sizeText: it.sizeText,
                            isDir: !!it.isDir,
                            addedMs: Date.now()
                        };
                        if (!existing[rec.path]) next.unshift(rec);
                    }
                    fs.shelfFiles = next.slice(0, 32);
                    fs.persist();
                    fs.setMessage("Added " + arr.length + " item(s) to Shelf", false);
                } catch (e) {}
            }
        }
    }

    Process {
        id: opRunner
        property bool refreshAfter: false
        property bool clearSelectedAfter: false
        property bool refreshGdriveAfter: false
        property string lastOut: ""
        property string lastErr: ""
        stdout: StdioCollector { onStreamFinished: opRunner.lastOut = String(text || "").trim() }
        stderr: StdioCollector { onStreamFinished: opRunner.lastErr = String(text || "").trim() }
        onExited: (code) => {
            fs.busy = false;
            if (code === 0) {
                fs.setMessage(opRunner.lastOut || "Done", false);
                if (opRunner.clearSelectedAfter) {
                    var gone = {};
                    for (var k = 0; k < fs.selectedPaths.length; k++) gone[fs.selectedPaths[k]] = true;
                    fs.shelfFiles = fs.shelfFiles.filter(function(item) { return !gone[item.path]; });
                    fs.selectedPaths = [];
                    fs.persist();
                }
                if (opRunner.refreshAfter) fs.browse(fs.currentDir);
                if (opRunner.refreshGdriveAfter) fs.listGdrive();
            } else {
                fs.setMessage(opRunner.lastOut || opRunner.lastErr || ("Failed (" + code + ")"), true);
            }
            opRunner.clearSelectedAfter = false;
            opRunner.refreshAfter = false;
            opRunner.refreshGdriveAfter = false;
        }
    }

    Process {
        id: rcloneCheck
        command: [
            "sh", "-c",
            "if ! command -v rclone >/dev/null 2>&1; then echo 'MISSING'; exit 0; fi; rclone listremotes 2>/dev/null || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                fs.rcloneChecking = false;
                var raw = String(text || "").trim();
                if (raw === "MISSING") {
                    fs.rcloneInstalled = false;
                    fs.gdriveRemote = "";
                    return;
                }
                fs.rcloneInstalled = true;
                var lines = raw.split(/\r?\n/).map(function(s) { return s.trim(); }).filter(function(s) { return s !== ""; });
                var chosen = "";
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].toLowerCase().indexOf("gdrive") >= 0 || lines[i].toLowerCase().indexOf("drive") >= 0) {
                        chosen = lines[i]; break;
                    }
                }
                if (!chosen && lines.length > 0) chosen = lines[0];
                fs.gdriveRemote = chosen;
                if (chosen !== "") fs.listGdrive();
            }
        }
    }

    Process {
        id: gdriveListRunner
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text || "[]");
                    var out = [];
                    for (var i = 0; i < Math.min(40, arr.length); i++) {
                        var it = arr[i];
                        var sz = Number(it.Size || 0);
                        var szTxt = it.IsDir ? "Folder" : (sz < 1024 ? sz + " B" : (sz < 1048576 ? (sz / 1024).toFixed(1) + " KB" : (sz / 1048576).toFixed(1) + " MB"));
                        out.push({
                            name: it.Name,
                            path: it.Path,
                            isDir: !!it.IsDir,
                            sizeText: szTxt
                        });
                    }
                    fs.gdriveEntries = out;
                } catch (e) {
                    fs.gdriveEntries = [];
                }
            }
        }
    }

    function persist() {
        file.setText(JSON.stringify({
            shelfFiles: fs.shelfFiles,
            currentDir: fs.currentDir
        }));
    }

    FileView {
        id: file
        path: fs.stateDir + "/notch-files.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", fs.stateDir]);
        var raw = file.text();
        if (raw) {
            try {
                var parsed = JSON.parse(raw);
                if (Array.isArray(parsed.shelfFiles)) fs.shelfFiles = parsed.shelfFiles;
                if (parsed.currentDir) fs.currentDir = String(parsed.currentDir);
            } catch (e) {}
        }
        fs.browse(fs.currentDir);
    }
}
