# Working in this repo

## Always open a PR

Finish every change by opening a pull request, without being asked: branch off `main`, commit, push, and `gh pr create`. CI deploys every PR to dev.dunderquest.com, which is where changes get reviewed, so a change that's only committed locally can't be seen yet. Never push straight to `main`: it deploys to production.

End with the PR link and a reminder that the preview will be on dev.dunderquest.com once CI finishes.

## Layout

See [README.md](README.md). The site is built by `site/build.py`. Each game has its own art and trailer tools under `games/<game>/tools/`, run from that game's folder.
