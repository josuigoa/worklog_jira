# Worklog Jira

A little NodeJs script that extract information from [worklog](http://github.com/ideckia/action_worklog) JSON file and creates Jira issues worklog (time spent in the issue).

## Arguments

You must call the script with some mandatory parameters:

* `worklogFile`: The path of the JSON file to extract the information
* `url`: The url of your Jira
* `u`: Jira username
* `p`: Jira password

## How does it work

Worklog JSON file structure looks like this:

```json
[
    {
        "day": "2022-06-01",
        "totalTime": "09:30",
        "exitTime": "16:15",
        "tasks": [
            {
                "start": "07:15",
                "finish": "08:45",
                "time": "01:30",
                "work": "my-issue-5"
            },
            {
                "start": "09:30",
                "finish": "11:30",
                "time": "02:00",
                "work": "gone out"
            }
        ]
    }
]

```

This script takes every day of the file and with every task of the day does this:

* Calls a Jira endpoint to check the _work_ endpoint exists.
  * If it doesn't exist, does nothing
  * If it does exist, calls Jira to create a worklog for that _day_ and time spent in the issue with the value of _time_
    * If the creation is successful, the _work_ will be overwritten with a `[DONE] ` prefix.

### Execution example

node app.js -worklogFile /path/to/worklog.json -url http://my.jira.local/ -u myJiraUser -p myJiraPass

What it does is:

* Calls Jira to check if the issue with key `my-issue-5` exists (let's imagine it actually exists)
  * Calls Jira to create a worklog for `my-issue-5` with the value _01:30_ the day _2022-06-01_
    * If it goes well now the _work_ value will be updated to `[DONE] my-issue-5`
* Calls Jira to check if `gone out` exists
  * It doesn't exists, so it is skipped