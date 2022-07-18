import haxe.Exception;
import haxe.ds.Option;
import WorklogUtils;

using StringTools;

class Sanitizer {
	static inline var DONE_PREFIX = '[DONE] ';
	static inline var ERROR_PREFIX = '[ERROR] ';
	static var worklogPath:String;
	static var mergeTimes:Bool;
	static var checkTime:Bool;

	static public function main() {
		if (!handleArguments())
			return;

		try {
			var worklogData = WorklogUtils.parse(worklogPath);
			var totalTimeMessages = [];
			for (dayData in worklogData) {
				if (mergeTimes)
					mergeTaskTimes(dayData);
				if (checkTime)
					switch checkTotalTime(dayData) {
						case Some(msg):
							totalTimeMessages.push(msg);
						case None:
					};
			}

			if (totalTimeMessages.length != 0)
				js.Node.process.stderr.write('Total times mismatched: \n * ${totalTimeMessages.join('\n * ')}');
			else
				trace('No problems in worklog file.');

			WorklogUtils.saveToFile(worklogPath, worklogData);
		} catch (e:haxe.Exception) {
			trace('Error. $e');
			return;
		}
	}

	static public function mergeTaskTimes(day:DayData) {
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
			return None;

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
			return Some('${day.day} / file total time [${day.totalTime}] / calculated total time [$totalTime]');

		return None;
	}

	static function handleArguments() {
		var arguments = Sys.args();

		for (i => a in arguments) {
			if (a == '-worklogFile')
				worklogPath = arguments[i + 1];
			if (a == '-checkTime')
				checkTime = true;
			if (a == '-mergeTimes')
				mergeTimes = true;
		}

		if (worklogPath == null)
			trace('[-worklogFile /path/to/worklog.json] is mandatory.');

		if (!checkTime && !mergeTimes)
			trace('You must define one at least: -checkTime or -mergeTimes');

		return worklogPath != null && (checkTime || mergeTimes);
	}
}
