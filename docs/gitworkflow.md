# Git workflow guidelines

These are the workflow guidelines that are being used to develop and maintain the website.

## Application development task
1. Checkout and pull the latest commits from `develop`
2. Create new branch off `develop` following the [branch name standards](gitstandards.md)
3. Complete changes and add a commit message following [commit standards](gitstandards.md)
4. Create a new PR using `develop` as the target branch following the [PR standards](gitstandards.md)
5. Code Reviewer follows the [Code Review checklist](gitstandards.md) to make sure the code meets the standards and expectations of the task
6. Code Reviewer follows the testing instructions included in the PR description
7. Additionally, QA Engineer runs any manual tests using the [Testing](testing.md) documentation
8. Meanwhile, automated tests run in the pipeline
9. Code Reviewer approves PR or requests revisions
10. QA Engineer approves PR or requests revisions
11. If the PR is approved, the designated code maintainer merges the PR into the target branch using the appropriate [merge strategy](standards.md)
12. Code is deployed to DEV for testing in the cloud.gov environment
13. Approved code marked ready to release will be deployed to STAGE for final testing and approval
15. Work in STAGE will be deployed to PROD in the next scheduled release as a [standard release](releases.md)

## Hotfix development task
1. Checkout and pull the latest commits from `main`
2. Create new branch off `main` following the [branch name standards](gitstandards.md)
3. Complete changes and add a commit message following [commit standards](gitstandards.md)
4. Create a new PR using `hotfix/X.X.X` as the target branch following the [PR standards](gitstandards.md)
5. Code Reviewer follows the [Code Review checklist](gitstandards.md) to make sure the code meets the expectations of the task
6. Code Reviewer follows the testing instructions included in the PR description
7. Additionally, QA Engineer runs any manual tests using the [Testing](testing.md) documentation
8. Meanwhile, automated tests run in the pipeline
9. Code Reviewer approves PR or requests revisions
10. QA Engineer approves PR or requests revisions
11. If the PR is approved, the designated code maintainer merges the PR into the target branch using the appropriate [merge strategy](standards.md)
12. Approved code marked ready to release will be deployed to STAGE for final testing and approval
13. Designated code maintainer creates a PR from STAGE to DEV to sync changes down using appropriate [merge strategy](standards.md)
14. Work in STAGE is deployed to PROD as a [hotfix release](releases.md)
