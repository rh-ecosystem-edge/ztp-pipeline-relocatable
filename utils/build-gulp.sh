#!/bin/bash
# Builds documentation for each release in both HTML and PDF versions

# Before everything we run utils/build.sh
# build.sh will run asciidoctor in order to create the final html
sh utils/build.sh

# set all the releases for different kind of documents to manage:
# mydocs for releases
# mystaticdocs for static docs
# mydevprev for dev docs
myreleases=$(cat website/_data/releases.yml | grep release | cut -d ":" -f 2- | sort -u -r)

declare -a mydocs
readarray -t mydocs <<<$(cat website/_data/releases.yml | grep name | cut -d ":" -f 2- | sort -u)

mystaticreleases=$(cat website/_data/static.yml | grep release | cut -d ":" -f 2- | sort -u -r)

declare -a mystaticdocs
readarray -t mystaticdocs <<<$(cat website/_data/static.yml | grep name | cut -d ":" -f 2- | sort -u)

mydevreleases=$(cat website/_data/devprev.yml | grep release | cut -d ":" -f 2- | sort -u -r)
declare -a mydevprev
readarray -t mydevprev <<<$(cat website/_data/devprev.yml | grep name | cut -d ":" -f 2- | sort -u)

# Empty index
>website/index.html

# Create website/index.html
# This index.html will be the docs index
# Builds an href for each doc:release

# Versioned release documents
echo "<h2>Versioned</h2>" >>website/index.html
echo "<ul>" >>website/index.html
for release in ${myreleases}; do
    for doc in "${mydocs[@]}"; do
        doc=$(echo "${doc}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        echo "<li><a href=\"${release}/${doc}\">${release}-${doc}</a></li>" >>website/index.html
    done
done
echo "</ul>" >>website/index.html

# Static documents
echo "<h2>Static</h2>" >>website/index.html
echo "<ul>" >>website/index.html
for release in ${mystaticreleases}; do
    for doc in "${mystaticdocs[@]}"; do
        doc=$(echo "${doc}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        echo "<li><a href=\"${release}/${doc}\">${release}-${doc}</a></li>" >>website/index.html
    done
done
echo "</ul>" >>website/index.html

# Development documents
echo "<h2>Development</h2>" >>website/index.html
echo "<ul>" >>website/index.html
for release in ${mydevreleases}; do
    for doc in "${mydevprev[@]}"; do
        doc=$(echo "${doc}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        echo "<li><a href=\"${release}/${doc}\"> ${release}-${doc}</a></li>" >>website/index.html
    done
done

echo "</ul>" >>website/index.html
