%%%-------------------------------------------------------------------
%%% Created : by comptekki May 12, 2010
%%% Desc.   : erlang based utility to track pages printed.
%%%
%%% @author comptekki
%%%
%%% @doc	pgprt is an erlang based utility to track pages printed on
%%%			a printer by scraping page total from printer.
%%%
%%%			Scraped total goes in to a postgresql table.
%%% @end
%%%
%%%-------------------------------------------------------------------
-module(prt).

-import(lists, [map/2, foldl/3, reverse/1, flatten/1]).

-include("prt.hrl").

-export([
	start/0, stop/1, stop/0, init/0, init2/0, dodrop/0, chk/0,
	chk_pg_cnt/1, getc/0, insert_pgcnt/1, run/0, tot/0,
	fill_table/0, chk_cons/0, get_tables/0, get_columns/1, fill_tab_t/0
	]).

init() ->
	{ok, Db} = pgsql:connect(?HOST, ?USERNAME, ?PASSWORD, [{database, ?DB}]),
	{_,_,Res}=pgsql:squery(Db, "create table page_count (page_count_id serial primary key, page_count_count integer, page_count_pdate date, page_count_ptime time)"),
	pgsql:close(Db),
	Res.

init2() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[Res]}=pgsql:squery(Db, "create table test (test_id serial primary key, test_akey integer, test_field1 integer, test_field2 integer)"),
	pgsql:terminate(Db),
	Res.
	
 dodrop() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[Res]}=pgsql:squery(Db, "drop table page_count"),
	{_,[Res]}=pgsql:squery(Db, "drop table test"),
	pgsql:terminate(Db),
	Res.
	
	
	start() ->
%		Pid=

		spawn_link(?MODULE, run, []).
		
%		,io:format("spawn Pid: ~w~n", [Pid]).

run() ->
%	Id_Table=ets:new(start_id_table, []),
%	{ok, TRef}=

	timer:apply_interval(timer:seconds(?SECONDS), prt, getc, []),

%	ets:insert(Id_Table, {id, TRef}),
%	io:format("Id_Table: ~w~n", [Id_Table]),
%	io:format("Id_Table lookup: ~w~n", [ets:lookup(Id_Table, id)]),
    prt_timer_loop().

prt_timer_loop() ->
	receive
		stop ->  
			ok;
		_ ->
			prt_timer_loop()
	end.

stop(Id_Table) ->
	[{_,TRef}] = ets:lookup(Id_Table, id),
	timer:cancel(TRef).
	
stop() ->
	timer:cancel().

get_tables() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[{_,_,Res}]}=pgsql:squery(Db, "select tablename from pg_tables where schemaname='public'"),
	pgsql:terminate(Db),
	Res.

get_columns(Table) ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[{_,_,Res}]}=pgsql:squery(Db, "select column_name from information_schema.columns where table_name ='" ++ Table ++ "'"),
	pgsql:terminate(Db),
	Res.
	
getc() ->
	inets:start(),
    {ok, {_StatusLine, _Headers, Body}} = httpc:request(?URL),
    Lines = string:tokens(Body, "\r\n"),
    PageCount = extract_page_count(lists:nth(?MAGIC_LINE_NUMBER, Lines)),
	Count=chk_pg_cnt(PageCount),
<<<<<<< HEAD
%	io:format("Count: ~p~n",[Count]),
	

%%	io:format("~p",[lists:flatten([tuple_to_list(erlang:localtime())|Count])]),
	case PageCount == Count of
=======
%%	io:format("~p",[lists:flatten([tuple_to_list(erlang:localtime())|Count])]),
	if
		length(Count) == 0 ->
			insert_pgcnt(PageCount); 
%,
%%			io:format("~n");
>>>>>>> 7c726cde5daa61a9002bc900f99cd520e69006dc
		true ->
			ok;
		_ ->
			insert_pgcnt(PageCount)
    end,
    ok.

extract_page_count("<B>Page&nbsp;Counter</B></TD><TD>" ++ Rest) ->
       {Count, _} = string:to_integer(Rest),
       Count.
	
insert_pgcnt(PageCount) ->
	{ok, Db} = pgsql:connect(?HOST, ?USERNAME, ?PASSWORD, [{database, ?DB}]),
	MkDate=fun(D) -> integer_to_list(erlang:element(1,D)) ++ "-" ++ integer_to_list(erlang:element(2,D)) ++ "-" ++  integer_to_list(erlang:element(3,D)) end,
	MkTime=fun(T) -> integer_to_list(erlang:element(1,T)) ++ ":" ++ integer_to_list(erlang:element(2,T)) ++ ":" ++  integer_to_list(erlang:element(3,T)) end,
%	Sq="insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (" ++ integer_to_list(PageCount) ++ ",'" ++ MkDate(erlang:date()) ++ "','"++ MkTime(erlang:time()) ++ "')",
%	io:format("insert: ~p~n",[Sq]),
	pgsql:squery(Db, "insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (" ++ integer_to_list(PageCount) ++ ",'" ++ MkDate(erlang:date()) ++ "','"++ MkTime(erlang:time()) ++ "')"),
	pgsql:close(Db).

chk_pg_cnt(PageCount) ->
	{ok, Db} = pgsql:connect(?HOST, ?USERNAME, ?PASSWORD, [{database, ?DB}]),
%	io:format("query: ~p~n",["SELECT page_count_count FROM page_count where page_count_count=" ++ integer_to_list(PageCount)]),
	{_,_,Res}=pgsql:squery(Db, "SELECT page_count_count FROM page_count where page_count_count=" ++ integer_to_list(PageCount)),
%	io:format("Res: ~p~n",[Res]),
	case length(Res) of
		0 -> Ret=0;
		_ ->
			[{Res2}]=Res,
			Ret=list_to_integer(binary_to_list(Res2))
	end,
	pgsql:close(Db),
	Ret.

% {ok,[{"SELECT", [{desc,2,"count",int4,text,4,-1,16407}], [[6169]]}]}
      
% {ok,[{"SELECT", [{desc,2,"count",int4,text,4,-1,16407}],[]}]}

chk() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[{_,_,[[Res]]}]}=pgsql:squery(Db, "SELECT count(*) FROM page_count"),
	pgsql:terminate(Db),
	io:format("~w~n", [Res]).

chk_cons() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[{_,_,Res}]}=pgsql:squery(Db, "select procpid from pg_stat_activity"),
	pgsql:terminate(Db),
	io:format("~w~n", [Res]).
	
fill_tab_t() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	Test = f(10000, "insert into test default values"),
	lists:map(fun(Row) -> pgsql:squery(Db, Row) end, Test),
	pgsql:terminate(Db),
	ok.

tot() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	{_,[{_,_,[[Res]]}]}=pgsql:squery(Db, "SELECT count(*) FROM page_count"),
	pgsql:terminate(Db),
	io:format("~w~n", [Res]).

f(0, A) ->
        [A];
f(N, A) ->
        [A | f(N-1, A)].
        
        
	
fill_table() ->
	{ok, Db} = pgsql:connect(?HOST, ?DB, ?USERNAME, ?PASSWORD),
	Page_Count = 
		[
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (5967,'2010-05-11','07:58:30');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (5968,'2010-05-11','08:47:48');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (5974,'2010-05-11','09:22:48');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (5979,'2010-05-11','13:10:27');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6013,'2010-05-12','09:47:33');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6014,'2010-05-12','10:35:48');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6039,'2010-05-12','13:29:40');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6042,'2010-05-12','15:28:44');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6043,'2010-05-13','09:47:36');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6044,'2010-05-13','10:02:36');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6045,'2010-05-13','11:37:36');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6046,'2010-05-13','11:57:36');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6092,'2010-05-13','17:06:42');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6114,'2010-05-14','08:56:42');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6115,'2010-05-14','10:21:42');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6116,'2010-05-14','11:03:48');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6117,'2010-05-14','12:45:32');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6118,'2010-05-14','13:58:41');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6119,'2010-05-18','12:02:39');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6120,'2010-05-18','13:32:38');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6121,'2010-05-18','13:47:39');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6123,'2010-05-18','15:35:00');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6125,'2010-05-18','16:55:37');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6127,'2010-05-19','09:55:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6133,'2010-05-19','10:15:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6141,'2010-05-19','10:20:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6148,'2010-05-19','10:25:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6155,'2010-05-19','10:30:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6157,'2010-05-19','10:35:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6159,'2010-05-19','11:45:02');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6169,'2010-05-19','15:59:08');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6179,'2010-05-20','19:36:08');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6180,'2010-05-20','19:43:31');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6181,'2010-05-20','19:54:59');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6182,'2010-05-20','20:25:10');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6183,'2010-05-20','21:15:40');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6193,'2010-05-21','14:00:00');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6203,'2010-05-24','10:55:31');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6205,'2010-05-24','13:51:52');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6206,'2010-05-24','14:55:17');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6207,'2010-05-24','15:8:22');",
"insert into page_count (page_count_count,page_count_pdate,page_count_ptime) values (6209,'2010-05-24','16:28:30');"
	],
	
	lists:map(fun(Row) -> pgsql:squery(Db, Row) end, Page_Count),
	pgsql:terminate(Db),
	ok.
