#!/bin/bash
#
# ./git-switch-remote.sh to-repo source-repo=pwd current-origin-name
#

set -e

function die {
    # exites from the script with the reason message
    echo "$@, exited"
    exit 1
}

repo=$1

if [ -z "$repo" ]
then
    die "target repository not set"
fi


source="$(realpath ${2:-$PWD})"
if [ ! -d "$source" ]
then 
    die "not a directory: $source"
fi

t="$source/.git"
if [ ! -d "$t" ]
then 
    die "not a git repo: $t"
fi

#
# cd to repo dir
#
cd $source


origin=$3
if [ -z $origin ]
then
    remotes="$(git remote)"
    if [ "$(echo $remotes | wc -w)" != "1" ]
    then 
        echo -e "Found origins\n$remotes"
        die "Cannot select a one origin, no origin was specified"
    else
        origin="$remotes"
        echo "Select origin: $origin" 
    fi
else
    if git remote | xargs | grep -v $origin > /dev/null
    then 
        die "Origin $origin not found in repo $source"
    fi
fi


local_up_remote=""

while read branch
do  
    set +e 
    upstream=$(git rev-parse --abbrev-ref $branch@{upstream} 2>/dev/null)
    if [[ $? != 0 ]]
    then
        continue
    fi
    set -e

    rname="${upstream#*/}"
    oname="${upstream%%/*}"

    echo "$branch --tracks> $upstream"

    local_up_remote="${local_up_remote}\n$branch $oname $rname"
  
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

neworigin=neworigin

if [ -z "${local_up_remote}" ]
then 
    echo "Remote branches not found"
else 

    if git remote | xargs | grep $neworigin > /dev/null
    then
        branch_origins="$(echo -e "${local_up_remote}" | cut -f2 | sort | uniq | xargs)"

        if echo "${branch_origins}" | grep -v $neworigin > /dev/null
        then
            git remote rm $neworigin >/dev/null
        else
            echo "Warning: temp origin $neworigin is already tracked by some branches"
        fi
    fi

    if git remote | xargs | grep -v $neworigin > /dev/null
    then 
        git remote add $neworigin $repo
    fi 

    git fetch $neworigin

fi


echo -e "${local_up_remote}" | while read line
do 
    origin_name=$(echo $line | cut -d' ' -f2)

    if [ "${origin_name}" != "$origin" ]
    then
        continue
    fi

    local_branch=$(echo $line | cut -d' ' -f1)
    remote_branch=$(echo $line | cut -d' ' -f3)

    echo "Push to new origin: ${local_branch} -> ${remote_branch}"
    git pull $neworigin ${local_branch}:${remote_branch} || true 
    git push -u $neworigin ${local_branch}:${remote_branch}
    
done


git remote rename $origin old-$origin
git remote rename $neworigin $origin

