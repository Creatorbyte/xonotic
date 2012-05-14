#!/bin/sh

set -e

action=$1
outdir=$2
repodir=$3

branches()
{
	git for-each-ref 'refs/remotes' | grep -vE '	refs/remotes/([^/]*/HEAD|.*/archived/.*)$'
}

escape_html()
{
	sed -e 's/&/\&amp;/g; s/</&lt;/g; s/>/&gt;/g'
}

to_rss()
{
	outdir=$1
	name=$2
	masterhash=$3
	hash=$4
	branch=$5
	repo=$6
	if [ -n "$repo" ]; then
		repo=" in $repo"
	fi

	filename=`echo -n "$name" | tr -c 'A-Za-z0-9' '_'`.xml
	outfilename="$outdir/$filename"
	datetime=`date --rfc-2822`
	branch=`echo "$branch" | escape_html`
	repo=`echo "$repo" | escape_html`

	if ! [ -f "$outfilename" ]; then
		cat >"$outfilename" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
	<title>Merge conflicts for $name</title>
	<link>http://git.xonotic.org/</link>
	<description>...</description>
	<lastBuildDate>$datetime</lastBuildDate>
	<ttl>3600</ttl>
	<atom:link href="http://de.git.xonotic.org/conflicts/$filename" rel="self" type="application/rss+xml" />
EOF
	fi
	cat >>"$outfilename" <<EOF
	<item>
		<title>$branch$repo ($hash)</title>
		<link>http://git.xonotic.org/?p=xonotic/netradiant.git;a=shortlog;h=refs/heads/$name/$branch</link>
		<guid isPermaLink="false">http://de.git.xonotic.org/conflicts/$filename#$hash-$masterhash</guid>
		<description><![CDATA[
EOF

	escape_html >>"$outfilename"

	cat >>"$outfilename" <<EOF
		]]></description>
	</item>
EOF
}

finish_rss()
{
	cat <<EOF >>"$1"
</channel>
</rss>
EOF
}

if [ -z "$outdir" ]; then
	set --
fi

case "$action" in
	--init)
		rm -rf "$outdir"
		mkdir -p "$outdir"
		;;
	--finish)
		for f in "$outdir"/*; do
			[ -f "$f" ] || continue
			finish_rss "$f"
		done
		;;
	--add)
		masterhash=$(
			(
				if [ -n "$repodir" ]; then
					cd "$repodir"
				fi
				git rev-parse HEAD
			)
		)
		(
		 	if [ -n "$repodir" ]; then
				cd "$repodir"
			fi
			branches
		) | while read -r HASH TYPE REFNAME; do
			echo >&2 -n "$repodir $REFNAME..."
			out=$(
				(
					if [ -n "$repodir" ]; then
						cd "$repodir"
					fi
					git reset --hard "$masterhash" >/dev/null 2>&1
					if out=`git merge --no-commit -- "$REFNAME" 2>&1`; then
						good=true
					else
						good=false
						echo "$out"
					fi
					git reset --hard "$masterhash" >/dev/null 2>&1
				)
			)
			if [ -n "$out" ]; then
				b=${REFNAME#refs/remotes/[^/]*/}
				case "$b" in
					*/*)
						n=${b%%/*}
						;;
					*)
						n=divVerent
						;;
				esac
				echo "$out" | to_rss "$outdir" "$n" "$masterhash" "$HASH" "$b" "$repodir"
				echo >&2 " CONFLICT"
			else
				echo >&2 " ok"
			fi
		done
		;;
	*)
		echo "Usage: $0 --init OUTDIR"
		echo "       $0 --add OUTDIR [REPODIR]"
		echo "       $0 --finish OUTDIR"
		exit 1
		;;
esac
