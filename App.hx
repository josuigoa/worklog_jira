package;

import WorklogUtils;
import datetime.DateTime;

using StringTools;

class App {
	static inline var JIRA_REST_PATH = 'rest/api/2/issue';
	static inline var DONE_PREFIX = '[DONE] ';
	static inline var ERROR_PREFIX = '[ERROR] ';
	static var logStream:js.node.fs.WriteStream;
	static var url:String;
	static var worklogPath:String;
	static var user:String;
	static var password:String;
	static var encodedUserPass:String;

	static public function main() {
		if (!handleArguments())
			return;

		encodedUserPass = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString('$user:$password'));
		var time = DateTime.local().format('%F %T').replace(':', '.');
		var logFile = haxe.io.Path.directory(worklogPath) + '/$time.log';
		sys.io.File.saveContent(logFile, '');

		logStream = js.node.Fs.createWriteStream(logFile);
		logStream.on('error', (error) -> {
			trace('An error occured while writing to the file. Error: ${error.message}');
		});

		var worklogData = WorklogUtils.parse(worklogPath);
		manageTasks(worklogData).then((_) -> WorklogUtils.saveToFile(worklogPath, worklogData));
	}

	static function manageTasks(worklogData:Array<DayData>):js.lib.Promise<Bool> {
		return new js.lib.Promise((resolve, reject) -> {
			var doneTasks = 0;
			var allTasks = 0;
			inline function addDone() {
				doneTasks++;
				if (doneTasks == allTasks)
					resolve(true);
			}

			var hour = 'T08:00:00.000+0000';

			for (dayData in worklogData) {
				for (task in dayData.tasks) {
					if (task.work == null || task.work.startsWith(DONE_PREFIX) || task.work.startsWith(ERROR_PREFIX))
						continue;
					allTasks++;
					existsTask(task.work).then(exists -> {
						var logTaskId = '[${dayData.day}/${task.work}]';
						if (exists) {
							log('$logTaskId does exist, creating worklog in Jira.');
							addTaskWorklog(task.work, dayData.day + hour, task.time).then((_) -> {
								log('$logTaskId: ${task.time} hours added.');
								task.work = DONE_PREFIX + task.work;
								addDone();
							}).catchError(e -> {
								log('$logTaskId: Error when "addTaskWorklog": $e');
								task.work = ERROR_PREFIX + task.work;
								addDone();
							});
						} else {
							log('$logTaskId issue does not exist in Jira.');
							task.work = ERROR_PREFIX + task.work;
							addDone();
						}
					}).catchError(e -> {
						log('[${dayData.day}/${task.work}] Error when "existsTask": $e');
						task.work = ERROR_PREFIX + task.work;
						addDone();
					});
				}
			}
		});
	}

	static function existsTask(taskId:String):js.lib.Promise<Bool> {
		return new js.lib.Promise((resolve, reject) -> {
			var http = createHttp(taskId);
			http.onError = reject;
			http.onData = (data) -> {
				var error:{errorMessages:Array<String>, errors:Any} = haxe.Json.parse(data);
				resolve(error.errorMessages == null);
			};
			http.request();
		});
	}

	static function addTaskWorklog(taskId:String, day:String, ?time:DateTime):js.lib.Promise<Bool> {
		return new js.lib.Promise((resolve, reject) -> {
			if (time == null) {
				reject('[$taskId] "time" is null.');
				return;
			}

			var http = createHttp(taskId);
			var seconds = time.getTime();
			http.setPostData(haxe.Json.stringify({
				started: day,
				timeSpentSeconds: seconds
			}));
			http.onError = reject;
			http.onData = (_) -> {
				resolve(true);
			}
			http.request(true);
		});
	}

	static function createHttp(taskId:String) {
		var endpoint = '$url$JIRA_REST_PATH/$taskId/worklog';
		var http = new haxe.Http(endpoint);
		http.addHeader('Authorization', 'Basic $encodedUserPass');
		http.addHeader("Content-type", "application/json");
		return http;
	}

	static function handleArguments() {
		var arguments = Sys.args();

		for (i => a in arguments) {
			if (a == '-url')
				url = arguments[i + 1];
			if (a == '-u')
				user = arguments[i + 1];
			if (a == '-p')
				password = arguments[i + 1];
			if (a == '-worklogFile')
				worklogPath = arguments[i + 1];
		}

		if (worklogPath == null)
			trace('[-worklogFile /path/to/worklog.json] is mandatory.');
		if (user == null)
			trace('[-u erabiltzaileIzena] is mandatory.');
		if (password == null)
			trace('[-p pasahitza] is mandatory.');
		if (url == null) {
			trace('[-url http://jira.local] is mandatory.');
		} else {
			if (!url.endsWith('/'))
				url += '/';
		}

		return worklogPath != null && user != null && password != null && url != null;
	}

	static function log(v:Dynamic, ?info:haxe.PosInfos) {
		var time = DateTime.local().format('%F %T');
		var filePath = info.fileName;
		var filename = StringTools.replace(filePath.substr(filePath.lastIndexOf('/') + 1), '.hx', '');
		var text = '$time [$filename.${info.methodName}:${info.lineNumber}]: $v';
		logStream.write(text + '\n');
	}
}
