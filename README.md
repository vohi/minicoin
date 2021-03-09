# minicoin

minicoin is a tool designed for building and testing Qt on multiple platforms,
using virtual machines that run either locally, or in the cloud.

# Documentation

For documentation of minicoin, see the [project wiki](-/wikis/home).

# Teaser

```
$ cd ~/qt5/qtbase
$ minicoin run build ubuntu2004
$ cd ~/my_project
$ minicoin run build ubuntu2004
```

This will first build qtbase from the local ~/qt5/qtbase directory on the
ubuntu2004 box, and then build the project in ~/my_project on the same box,
using the qtbase that was built just before.
