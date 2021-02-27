# How to make a release

```
# commit your changes
# push them to trigger a build
# if you're ready, make the release below
next_version="0.0.14"
git checkout master && git pull && git tag -s ${next_version} -m "" && git push --tags
```