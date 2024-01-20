#!/bin/bash

# memoの履歴は対して管理するメリットがないので、
# 重要でないcommitとpushにできるだけ時間を割きたくない。
# 保存毎にコミットしてpushしてもいいくらいだと考えている。
# そこでcommitとpushをスクリプトにしてある程度自動化する。

script_dir=$(cd $(dirname $0); pwd)
cd $script_dir

auto_commit_and_push(){
	t=`date "+%Y.%m.%d.%H:%M.%S"`
	msg="docs: update $t"

	git add -A .
	git commit -nm "$msg"
	git pull -f origin master
	git push -f origin master
}

auto_commit_and_push


