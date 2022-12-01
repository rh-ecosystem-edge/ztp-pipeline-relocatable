# Command line tool

This directory contains the source of the `oc-ztp` command line tool.

# Preparing your development environment

To prepare your development environment you will need to have Go 1.19 and Python
3 installed and added to your `PATH` environment variable. Python is needed to
run the `build.py` script which simplifies setting up the environment and
running the build and test commands, and Go is needed to build the binary.

The recommended setup is to use the [direnv](https://direnv.net) tool to create
an environment specific for this project. Check the `direnv` documentation to
learn how to install and use it.

Lets say that you have decided to use directory
`/files/projects/ztp-pipeline-relocatable` for the project files, you can clone
the source and prepare the environment like this:

```
$ mkdir -p /files/projects/ztp-pipeline-relocatable
$ cd /files/projects/ztp-pipeline-relocatable
$ git clone git@github.com:rh-ecosystem-edge/ztp-pipeline-relocatable.git repository
```

Note that that clones the source code inside an additional `repository`
directory.  That way you can put other files, like the `direnv` configuration in
the parent directory and avoid accidentally commiting them. For example, create
a Python virtual environment inside the `.venv` directory:

```
$ cd /files/projects/ztp-pipeline-relocatable
$ python -m venv .venv
```

And configure `direnv` to load your Python and Go configuration:

```
$ cat > .envrc <<.
# Configure Python:
export VIRTUAL_ENV="${PWD}/.venv"
PATH_add "${PWD}/.venv/bin"

# Configure Go:
export GOROOT="/files/software/go1.19"
export GOPATH="${PWD}/.local"
export GOBIN="${PWD}/.local/bin"
PATH_add "${GOROOT}/bin"
PATH_add "${PWD}/.local/bin"
.
```

This is assuming that you have Go installed in `/files/software/go1.19`, adjust
the `GOROOT` environment variable if you have it in a different place.

If you have configured `direnv` correctly then each time you change into the
project directory it will load the settings from that `.envrc` file. The first
time you will also need to give `direnv` permission to use that file running
`direnv allow`.

Once you have both Python and Go working you can use the `build.py` script to
prepare the rest of the tools that you will need, in particular
[ginkgo](https://github.com/onsi/ginkgo) testing framework and the
[golangci-lint](https://github.com/golangci/golangci-lint) linter. Fist install
the Python requirements:

```
$ cd /files/projects/ztp-pipeline-relocatable/repository/go
$ pip install -r requirements.txt
```

Then use the `setup` command of the `build.py` script:

```
$ cd /files/projects/ztp-pipeline-relocatable/repository/go
$ ./build.py setup
Installing ginkgo
Installing golangci-lint
```

# Building and running the tests

You can use the `go`, `ginkgo` and `golangci-lint` commands directly, or use the
`./build.py` script to run them with the usal options. For example, to build the
binary you will want to run `go build -o oc-ztp`, because otherwise the binary
will be named after the name of the directory (which happes to be `go`). You can
do that our use the corresponding `build.py` option. For building the binary:

```
$ ./build.py build
$ ./oc-ztp version
Build commit: 853aba5e31848d566b4e541e9a164e81874b6379
Build time: 2022-12-01T15:35:36Z
```

For running the tests:

```
$ ./build.py test
[1669914015] Tool - 6/6 specs •••••• SUCCESS! 397.849µs PASS
[1669914015] Version command - 1/1 specs • SUCCESS! 229.633µs PASS
```

For running the linter:

```
$ ./build.py lint
```
