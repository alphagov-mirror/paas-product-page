# GOV.UK PaaS Product Page

This is the source for the PaaS product page at https://www.cloud.service.gov.uk/

It is a Ruby/Sinatra app that makes use of the GOV.UK Elements, Frontend Toolkit and Template libraries.

## Configuration

The following environment variables should be set for correct deployment:

| variable | required | description |
|---|---|---|
| `ZENDESK_URL` | yes | endpoint url (ie "https://accountname.zendesk.com/api/v2") |
| `ZENDESK_USER` | yes | user for the api |
| `ZENDESK_TOKEN` | yes | token for the api |
| `ZENDESK_GROUP_ID` | no | group id to send the tickets to |

## Development

Dependencies:

* Ruby
* Bundler

You will find:

* The main application is `./app.rb`
* General content page in `./views/`
* Sass files in `./assets/stylesheets` (these will auto compile in dev mode)

To start the server locally in development mode:

```
ZENDESK_USER='REDACTED' \
ZENDESK_TOKEN='REDACTED' \
ZENDESK_URL=https://govuk.zendesk.com/api/v2 \
ZENDESK_GROUP_ID=123456789 \
make dev
```

To print the tickets to stdout rather than send to zendesk

```
FAKE_ZENDESK='true' \
make dev
```

## Deploying changes

This application should not be manually deployed to production. A pipeline
in [alphagov/paas-release-ci](https://github.com/alphagov/paas-release-ci)
will automatically deploy changes to the `master` branch.

You may wish to manually deploy this application to a different
environment in order to test some changes. We've provided a release
script for both `build` and `push` for your convinience.

Check in your changes to master.

```
$ ./release/push
```

Note: you will need the correct PaaS permissions as well as target your
desired organisation and space.
