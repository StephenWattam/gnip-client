# gnip-client
A small CLI for managing historical track tasks on gnip.

## Configuration
The script is intended to run with minimal configuration.  Simply set the Gnip account name in the constants at the top:

````ruby
API_ACCOUNT_NAME = 'LancasterUniversity'
API_ENDPOINT = "https://historical.gnip.com/accounts/#{API_ACCOUNT_NAME}/"
````

## Usage
To use the tool, call it from the command line and pass it a subcommand to run:

 * `list` --- Lists all current, rejected, queued and complete jobs.
 * `new` --- Sends a job spec to Gnip for them to start a quote.
 * `accept` --- Accept a quote and start the job.
 * `reject` --- Reject a quote.
 * `download` --- Retrieve all files from a completed job, storing them in a specific directory.

The tool uses UUIDs assigned by Gnip to specify which job you're working with.

### Specifying jobs
Job specification is done using the same format Gnip uses, as standalone JSON files.  Examples are provided in the `job_samples` directory:

````json
{
    "publisher"     : "twitter",
    "streamType"    : "track",
    "dataFormat"    : "activity-streams",
    "fromDate"      : "201601130000",
    "toDate"        : "201601150000",
    "title"         : "Testjob1",
    "rules" : [
        {"value": "teapot", "tag": "teapot"} 
    ]
}
````
