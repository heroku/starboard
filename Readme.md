# Starboard [![Build Status](https://travis-ci.org/heroku/starboard.svg)](https://travis-ci.org/heroku/starboard)

**WARNING: This code is an early-access release; we wrote it for ourselves and it still harbors a lot of Herokuisms. You will probably have to adapt it to your needs if you want to use it.**

Starboard is a tool which creates Trello boards for tracking the various tasks necessary when onboarding, offboarding, or crossboarding employees. We use Trello extensively within Heroku, and Starboard makes it easy to manage HR transitions from inside Trello.

The tasks themselves are authored as markdown files. When you run starboard, it resolves which tasks are relevant for the given employee and target team, and creates a new Trello board from the relevant markdown files.

Because the files are markdown (and stored in git), they're accessible to everyone in the company. Improvements to onboarding can come from anyone in the form of a pull request to the relevant guide.

### What does the UI look like?

Well, at Heroku, the frontend for creating boards looks like this:

![Starboard Web UI Screenshot](http://f.cl.ly/items/0V1p3d0u2K0k0j1y3B3X/Screen%20Shot%202014-08-14%20at%2011.46.07.png)

### How do I use it to create a Trello board?

Go to your deployed instance of Starboard, authorize with Trello, fill out the form and twiddle your thumbs while Starboard does its thing. When it finishes, you'll be redirected to your shiny new board.

### Where is it getting the data from?

Starboard depends on a specially-structured GitHub repository which contains the markdown guides. See the [template repository][1] for an example and more documentation.

## Starboard on Heroku

First, you'll need to create a GitHub repository containing the guides themselves. More information about the format of this repository is available as part of the [template repository][1].

### Security

Starboard limits access by means of checking that the user has access to a specific Trello organization.

**Warning**: users who don't have access to the Trello org cannot create boards, but can still access the starboard frontend and nothing prevents them from reverse-engineering the requests to fetch the raw markdown guides. **If this is a problem for you, limit access to the webapp by other means.**

### Deploy the app

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

#### OR

You can use the old way and
- Clone the code
- Create an app
- Add a memcached add-on
- Push the code

You will also have to set a few configuration variables.

### Config variables

- `TRELLO_ORGANIZATION` The trello organisation where the boards are created.
- `TRELLO_KEY` The trello API key that can be found at [https://trello.com/1/appKey/generate](https://trello.com/1/appKey/generate)
- `GITHUB_TOKEN` A GitHub access token to get the guides out of your repository. You can create an OAuth app and generate a token or use a personal access token. Please check [https://help.GitHub.com/articles/creating-an-access-token-for-command-line-use](https://help.GitHub.com/articles/creating-an-access-token-for-command-line-use) and use a private repo if you want to keep your content private.
- `GITHUB_REPO` An `orgname/reponame` identifier of the GitHub repository containing your guides.
- `HOOK_TOKEN` A generated secret used to create a web hook on GitHub to auto update the guides.

### Register a Webhook on GitHub

In order for starboard to be aware of updates to your guides, you will need to create a webhook.

Follow the [GitHub guide about webhooks creation][2] and add a hook for `https://<YOUR_HEROKU_APP>.herokuapp.com/guides?t=<YOUR_SECRET_HOOK_TOKEN>`

### First deploy

When you first deploy the app, you'll need to bootstrap the cache. There are two ways to accomplish this:

1. Update your guides after installing the app and setting up the webhook. The update will cause Starboard to cache your guides.

2. Trigger the same mechanism, but manually: `curl -X POST https://<YOUR_HEROKU_APP>.herokuapp.com/guides?t=<YOUR_SECRET_HOOK_TOKEN>`

### Ready to create boards

Hooray! Head over to `https://<YOUR_APP>.herokuapp.com` and go to town.

### GitHub token renewal if you created an OAuth application.

You can regenerate an access token via this curl command.

```
curl -vvv -X POST -H "Content-type: application/json" -u <USERNAME> -H "X-GitHub-OTP: <2FACODE IF YOU 2FA>" -d '{"scopes":["repo"],"note":"starboard access","client_id":"<APP_CLIENT_ID>","client_secret":"<APP_SECRET>"}' https://api.GitHub.com/authorizations
```

[1]: https://GitHub.com/heroku/starboard-docs-template
[2]: https://developer.GitHub.com/webhooks/creating/
