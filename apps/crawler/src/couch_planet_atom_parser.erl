%%% This file is part of the couch_planet package and is released under the
%%% Tumbolia Public License. See LICENSE for more details.
%%%
%%% @author Klaus Trainer <klaus.trainer@web.de>

%%% @doc couch_planet_atom_parser

-module(couch_planet_atom_parser).

-author('Klaus Trainer <klaus.trainer@web.de>').

-include("couch_planet.hrl").

%% user interface
-export([title/1, find_feed_entries/1,
         entry_link/1, entry_time/1, complete_entry/3]).

-import(couch_planet_parser, [xml2xml_text2json_text/1]).


% External API

%% @spec title(binary()) -> binary()
title(Xml) ->
    case get(title_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<title[^>]*?>(.*?)</title>">>,
            [caseless, dotall]),
        put(title_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Title]} -> xml2xml_text2json_text(Title)
    end.

%% @spec find_feed_entries(binary()) -> [binary()]
find_feed_entries(Xml) ->
    find_feed_entries(Xml, []).

%% @spec entry_link(binary()) -> binary() | false
entry_link(Xml) ->
    case get(entry_link_regex_1) of
    undefined ->
        {ok, MP1} = re:compile(<<"<link[^>]*?rel=['\"]alternate['\"][^>]*?href=['\"]([^'\"]*?)['\"][^>]*?>">>, [caseless, dotall]),
        {ok, MP2} = re:compile(<<"<link[^>]*?href=['\"]([^'\"]*?)['\"][^>]*?rel=['\"]alternate['\"][^>]*?>">>, [caseless, dotall]),
        put(entry_link_regex_1, MP1),
        put(entry_link_regex_2, MP2);
    MP1 ->
        ok
    end,
    case re:run(Xml, MP1, [{capture, [1], binary}]) of
    nomatch ->
        case re:run(Xml, get(entry_link_regex_2), [{capture, [1], binary}]) of
        nomatch -> false;
        {match, [Link]} -> xml2xml_text2json_text(Link)
        end;
    {match, [Link]} ->
        xml2xml_text2json_text(Link)
    end.

%% @spec entry_time(binary()) -> binary() | false
entry_time(Xml) ->
    case entry_updated(Xml) of
    <<>> ->
        case entry_published(Xml) of
        <<>> -> false;
        Value -> Value
        end;
    Value ->
        Value
    end.

%% @spec complete_entry(binary(), #entry{}, binary()) -> #entry{}
complete_entry(EntryData, Entry, Link) ->
    Summary = entry_content_or_summary(EntryData),
    ActorName = entry_author_name(EntryData),
    ActorLink = entry_author_uri(EntryData),
    #entry{object=Object0, actor=Actor0} = Entry,
    Object = Object0#object{id = Link, summary = Summary},
    Actor = Actor0#actor{link = ActorLink, name = ActorName},
    Entry#entry{title = title(EntryData), object = Object, actor = Actor}.


%% Internal API

find_feed_entries(Xml, Acc) ->
    case find_next_entry(Xml) of
    false ->
        Acc;
    {StartOffs, Length} ->
        Len = size(<<"</entry>">>),
        <<_:StartOffs/binary,Value:Length/binary,_:Len/binary,Rest/binary>> = Xml,
        find_feed_entries(Rest, [Value|Acc])
    end.

find_next_entry(Xml) ->
    case get(entry_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<entry>(.*?)</entry>">>,
            [caseless, dotall]),
        put(entry_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1]}]) of
    nomatch -> false;
    {match, [{StartOffs, Length}]} -> {StartOffs, Length}
    end.

%% @spec entry_content_or_summary(binary()) -> binary()
entry_content_or_summary(Xml) ->
    case entry_content(Xml) of
    <<>> -> entry_summary(Xml);
    Content -> Content
    end.

%% @spec entry_content(binary()) -> binary()
entry_content(Xml) ->
    case get(entry_content_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<content[^>]*?>(.*?)</content>">>,
            [caseless, dotall]),
        put(entry_content_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Content]} -> xml2xml_text2json_text(Content)
    end.

%% @spec entry_summary(binary()) -> binary()
entry_summary(Xml) ->
    case get(entry_summary_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<summary[^>]*?>(.*?)</summary>">>,
            [caseless, dotall]),
        put(entry_summary_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Summary]} -> xml2xml_text2json_text(Summary)
    end.

%% @spec entry_updated(binary()) -> binary()
entry_updated(Xml) ->
    case get(entry_updated_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<updated>(.*?)</updated>">>,
            [caseless, dotall]),
        put(entry_updated_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Value]} -> Value
    end.

%% @spec entry_published(binary()) -> binary()
entry_published(Xml) ->
    case get(entry_published_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<published>(.*?)</published>">>,
            [caseless, dotall]),
        put(entry_published_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Value]} -> Value
    end.

%% @spec entry_author_name(binary()) -> binary()
entry_author_name(Xml) ->
    case get(entry_author_name_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<name>(.*?)</name>">>,
            [caseless, dotall]),
        put(entry_author_name_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Value]} -> Value
    end.

%% @spec entry_author_uri(binary()) -> binary()
entry_author_uri(Xml) ->
    case get(entry_author_uri_regex) of
    undefined ->
        {ok, MP} = re:compile(<<"<uri>(.*?)</uri>">>,
            [caseless, dotall]),
        put(entry_author_uri_regex, MP);
    MP ->
        ok
    end,
    case re:run(Xml, MP, [{capture, [1], binary}]) of
    nomatch -> <<>>;
    {match, [Value]} -> Value
    end.
