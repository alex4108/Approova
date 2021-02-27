# How to make a release

```
next_version="0.0.2"
git checkout master && git pull && git tag -s ${next_version} -m "" && git push --tags
```