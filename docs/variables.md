# Variables

Following environment variables are available in all pipelines:

* **SCM_URL**

Url of SCM repository a build has been triggered for

* **SCM_BRANCH**

SCM branch

* **SCM_SHA**

SCM commit sha

* **SCM_COMMIT_MESSAGE**

SCM commit message

Following environment variables are available in [reporters](docs/reporters.md) pipelines:

* **BUILD_STATUS**

Pipeline build status

* **BUILD_WARN_CNT**

Number of warnings

* **BUILD_URL**

Http url for build report 

