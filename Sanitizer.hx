import WorklogUtils;

using StringTools;

class Sanitizer {
	static inline var DONE_PREFIX = '[DONE] ';
	static inline var ERROR_PREFIX = '[ERROR] ';
	static var worklogPath:String;

	static public function main() {
		if (!handleArguments())
			return;

		var worklogData = WorklogUtils.parse(worklogPath);
		for (dayData in worklogData) {
			mergeTaskTimesByDay(dayData);
			checkTotalTime(dayData);
		}

		WorklogUtils.saveToFile(worklogPath, worklogData);
	}

	static public function mergeTaskTimesByDay(day:DayData) {
		var mergedTasks:Array<Task> = [];

		var mergedFoundIndex;
		for (t in day.tasks) {
			if (t.work == null || t.work == '') {
				mergedTasks.push(t);
				continue;
			}

			mergedFoundIndex = -1;
			for (mi => mt in mergedTasks)
				if (mt.work == t.work)
					mergedFoundIndex = mi;

			if (mergedFoundIndex != -1)
				mergedTasks[mergedFoundIndex].time = mergedTasks[mergedFoundIndex].time.add(Second(Std.int(t.time.getTotalSeconds())));
			else
				mergedTasks.push(t);
		}

		day.tasks = mergedTasks;
	}

	static public function checkTotalTime(day:DayData) {
		if (day.tasks == null || day.tasks.length == 0)
			return;

		var totalTime:Time = 0;
		var processedDay = false;
		for (t in day.tasks) {
			if (t.work == null || t.work == '')
				continue;
			if (t.work.startsWith(DONE_PREFIX) || t.work.startsWith(ERROR_PREFIX)) {
				processedDay = true;
				break;
			}
			totalTime = totalTime.add(Second(Std.int(t.time.getTotalSeconds())));
		}

		if (!processedDay && day.totalTime.getTotalSeconds() != totalTime.getTotalSeconds())
			trace('${day.day} / file total time [${day.totalTime}] / calculated total time [$totalTime]');
	}

	static function handleArguments() {
		var arguments = Sys.args();

		for (i => a in arguments) {
			if (a == '-worklogFile')
				worklogPath = arguments[i + 1];
		}

		if (worklogPath == null)
			trace('[-worklogFile /path/to/worklog.json] is mandatory.');

		return worklogPath != null;
	}
}
