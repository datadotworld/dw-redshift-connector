# data.world & Redshift Connector

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/datadotworld/dw-redshift-connector)

## Getting Started

1. [Create a dataset](https://data.world/create-a-dataset) on data.world
2. You will need your own [Heroku](https://www.heroku.com) account
3. Deploy to Heroku by pressing the fancy-looking button above
    * This integration allows you to save all of the reports into one dataset or to multiple datasets. For the latter,
  take a look at the [Storing Reports in Multiple Datasets](#storing-reports-in-multiple-datasets) section.
    * `App name` is optional as one will be automatically assigned, but we recommend something descriptive
    * Take a look at the [Config Vars](#config-vars) section for more details on the individual configuration variables
    * The initial deployment will take a couple of minutes as it's pulling all of your historical data
4. Once deployment is done, click on 'Manage App' to go to the app's 'Overview' page
5. Under 'Installed add-ons', click on 'Heroku Scheduler'
6. Add a new job. The command to use is `update_reports`.
    * Note that times are in UTC. Use a timezone converter if you would like your job to run at a specific local time.

As an example, the following job is scheduled to run daily at 8 AM CDT:
![Daily Job](assets/scheduler-daily-job.png)

### Config Vars

 * 

### Support

For support, either create a [new issue](https://github.com/datadotworld/dw-redshift-connector/issues) here on
GitHub, or send an email to help@data.world.
