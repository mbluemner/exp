#!/bin/sh

/home/jay/Dev/scm/plt/racket/bin/raco make /home/jay/Dev/scm/github.jeapostrophe/git-index/git-index.rkt
/home/jay/Dev/scm/plt/racket/bin/racket -t /home/jay/Dev/scm/github.jeapostrophe/git-index/git-index.rkt -- $*
