pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 0
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property bool cpuReady: false
    property var previousCpuStats
    property var previousCoreStats: ({})
    property list<real> coreUsage: []

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        if (cpuReady) updateCpuUsageHistory()
    }

    function cpuStats(line) {
        const fields = line.trim().split(/\s+/).slice(1, 9).map(Number);
        return {total: fields.reduce((sum, value) => sum + value, 0), idle: fields[3] + (fields[4] ?? 0)};
    }

    function usageFrom(current, previous) {
        const elapsed = current.total - previous.total;
        return elapsed > 0 ? Math.max(0, Math.min(1, 1 - (current.idle - previous.idle) / elapsed)) : 0;
    }

	Timer {
		interval: 1000
        running: true 
        repeat: true
        triggeredOnStart: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 0)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const lines = fileStat.text().split("\n");
            if (lines[0]?.startsWith("cpu ")) {
                const stats = root.cpuStats(lines[0]);
                if (previousCpuStats) {
                    cpuUsage = root.usageFrom(stats, previousCpuStats);
                    cpuReady = true;
                }
                previousCpuStats = stats;

                const cores = {};
                const usage = [];
                for (const line of lines.slice(1)) {
                    const name = line.match(/^cpu\d+/)?.[0];
                    if (!name || usage.length >= 16) break;
                    cores[name] = root.cpuStats(line);
                    usage.push(previousCoreStats[name] ? root.usageFrom(cores[name], previousCoreStats[name]) : 0);
                }
                previousCoreStats = cores;
                coreUsage = usage;
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
