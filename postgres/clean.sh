#!/bin/bash


TIMEFORMAT=%R
USER=""
HOST=""
DB=""

function get_size {
  /usr/bin/psql -U $USER -h $HOST --tuples-only -d $DB -c "
  SELECT
     relname  as table_name,
     pg_size_pretty(pg_total_relation_size(relid)) As \"Total Size\",
     pg_size_pretty(pg_indexes_size(relid)) as \"Index Size\",
     pg_size_pretty(pg_relation_size(relid)) as \"Actual Size\"
     FROM pg_catalog.pg_statio_user_tables
     where relname = '$1';
  "
}

function reindex {
  /usr/bin/psql -U $USER -h $HOST -d $DB -c "
  reindex table $1;
  "
}
function vacuum {
  /usr/bin/psql -U $USER -h $HOST -d $DB -c "
  vacuum $1;
  "
}

function query_size {
case $1 in
	before)
	  WHEN0="had"
	  WHEN1="was"
	  WHEN2="was"
	;;
	after)
	  WHEN0="has"
	  WHEN1="is"
	  WHEN2="are"
	;;
esac
  IFS='|' read -ra ary <<< $(get_size $2)
  NAME=${ary[0]//[[:space:]]/}
  TOT=${ary[1]//[[:space:]]/}
  TBL=${ary[2]//[[:space:]]/}
  IDX=${ary[3]//[[:space:]]/}
  echo -n "Name: ${NAME} ${WHEN0} a total size of: ${TOT}, "
  echo "The table size ${WHEN1}: ${TBL} and all index ${WHEN2}: ${IDX}"
}

cat tbl.lst| while read line 
do
  query_size "before" $line
  echo "Let do some cleanup..."
  reindex $line
  vacuum $line
  query_size "after" $line
  echo "#### Table $line Done ####"
done
