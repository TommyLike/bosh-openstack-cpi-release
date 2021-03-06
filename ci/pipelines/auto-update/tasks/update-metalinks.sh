#!/usr/bin/env bash

set -e
set -x

cp -r metalink-src-in/. metalink-src-out
cd metalink-src-out/

# Update libyaml
libyaml_version=$(
git ls-remote --tags https://github.com/yaml/libyaml.git \
  | cut  -f2 \
  | grep -v '\^{}' \
  | grep -E '^refs/tags/.+$' \
  | sed  -E 's/^refs\/tags\/(.+)$/\1/'  \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -r --version-sort \
  | head -n1
)

libyaml_url=http://pyyaml.org/download/libyaml/yaml-${libyaml_version}.tar.gz
libyaml_size=$( curl -sI "$libyaml_url" | grep Content-Length | awk '{ print $2 }' | tr -cd '[:digit:]' )

cat > yaml_metalink<<EOF
<?xml version="1.0" encoding="utf-8"?>
<repository xmlns="https://dpb587.github.io/metalink-repository/schema-0.1.0.xsd">
    <metalink xmlns="urn:ietf:params:xml:ns:metalink">
      <file name="yaml-${libyaml_version}.tar.gz">
        <size>${libyaml_size}</size>
        <url>${libyaml_url}</url>
        <version>${libyaml_version}</version>
      </file>
    </metalink>
</repository>
EOF

# Update ruby

ruby_version=$(
git ls-remote --tags https://github.com/ruby/ruby.git \
  | cut  -f2 \
  | grep -v '\^{}' \
  | grep -E '^refs/tags/.+$' \
  | sed  -E 's/^refs\/tags\/(.+)$/\1/'  \
  | sed  's/^v//' \
  | tr   '_' '.' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -r --version-sort \
  | head -n1
)
ruby_version_download_folder=$(echo $ruby_version | sed 's/\.[0-9]$//')
ruby_url=https://cache.ruby-lang.org/pub/ruby/${ruby_version_download_folder}/ruby-${ruby_version}.tar.gz
ruby_size=$( curl -sI "$ruby_url" | grep Content-Length | awk '{ print $2 }' | tr -cd '[:digit:]' )
ruby_sha256=$(
curl -sL https://www.ruby-lang.org/en/downloads/ \
   | grep -E -1 "ruby-${ruby_version}.tar.gz\">Ruby" \
   | grep 'sha256' \
   | sed  's/^sha256: //; s/<\/li>$//' \
   | xargs
)

cat > ruby_metalink<<EOF
<?xml version="1.0" encoding="utf-8"?>
<repository xmlns="https://dpb587.github.io/metalink-repository/schema-0.1.0.xsd">
    <metalink xmlns="urn:ietf:params:xml:ns:metalink">
      <file name="ruby-${ruby_version}.tar.gz">
        <hash type="sha-256">${ruby_sha256}</hash>
        <size>${ruby_size}</size>
        <url>${ruby_url}</url>
        <version>${ruby_version}</version>
      </file>
    </metalink>
</repository>
EOF

# Update bundler

bundler_version=$(
git ls-remote --tags https://github.com/bundler/bundler.git \
  | cut -f2 \
  | grep -v '\^{}' \
  | grep -E '^refs/tags/.+$' \
  | sed  -E 's/^refs\/tags\/(.+)$/\1/'  \
  | sed  's/^v//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -r --version-sort \
  | head -n1
)
bundler_url=https://rubygems.org/downloads/bundler-${bundler_version}.gem
bundler_size=$( curl -sI "$ruby_url" | grep Content-Length | awk '{ print $2 }' | tr -cd '[:digit:]' )
bundler_sha256=$( curl -sL https://rubygems.org/gems/bundler/versions/${bundler_version} | grep -A1 'gem__sha' | grep -v 'gem__sha' | xargs )

cat > bundler_metalink<<EOF
<?xml version="1.0" encoding="utf-8"?>
<repository xmlns="https://dpb587.github.io/metalink-repository/schema-0.1.0.xsd">
    <metalink xmlns="urn:ietf:params:xml:ns:metalink">
      <file name="bundler-${bundler_version}.gem">
        <hash type="sha-256">${bundler_sha256}</hash>
        <size>${bundler_size}</size>
        <url>${bundler_url}</url>
        <version>${bundler_version}</version>
      </file>
    </metalink>
</repository>
EOF

# Update rubygems
rubygems_version=$(
git ls-remote --tags https://github.com/rubygems/rubygems.git \
  | cut -f2 \
  | grep -v '\^{}' \
  | grep -E '^refs/tags/.+$' \
  | sed  -E 's/^refs\/tags\/(.+)$/\1/'  \
  | sed  's/^v//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -r --version-sort \
  | head -n1
)
rubygems_url=https://rubygems.org/rubygems/rubygems-${rubygems_version}.tgz
rubygems_size=$( curl -sI "${rubygems_url}" | grep Content-Length | awk '{ print $2 }' | tr -cd '[:digit:]' )

cat > rubygems_metalink<<EOF
<?xml version="1.0" encoding="utf-8"?>
<repository xmlns="https://dpb587.github.io/metalink-repository/schema-0.1.0.xsd">
    <metalink xmlns="urn:ietf:params:xml:ns:metalink">
      <file name="rubygems-${rubygems_version}.tar.gz">
        <size>${rubygems_size}</size>
        <url>${rubygems_url}</url>
        <version>${rubygems_version}</version>
      </file>
    </metalink>
</repository>
EOF

echo "Looking for new package versions of libyaml, bundler, rubygems, or ruby"
git add .
git diff --cached --exit-code || exit_code=$?
if [ -v exit_code ]; then
echo "Creating new commit request"
  git add .
  git config --global user.email cf-bosh-eng@pivotal.io
  git config --global user.name CI
  git commit -m "Bump package version"
else
echo "No new libyaml, bundler, rubygems, or ruby version found"
fi
