-module(ash_ops_query).
-export([parse/1,file/1]).
-define(p_anything,true).
-define(p_charclass,true).
-define(p_choose,true).
-define(p_label,true).
-define(p_not,true).
-define(p_one_or_more,true).
-define(p_optional,true).
-define(p_scan,true).
-define(p_seq,true).
-define(p_string,true).
-define(p_zero_or_more,true).



-spec file(file:name()) -> any().
file(Filename) -> case file:read_file(Filename) of {ok,Bin} -> parse(Bin); Err -> Err end.

-spec parse(binary() | list()) -> any().
parse(List) when is_list(List) -> parse(unicode:characters_to_binary(List));
parse(Input) when is_binary(Input) ->
  _ = setup_memo(),
  Result = case 'query'(Input,{{line,1},{column,1}}) of
             {AST, <<>>, _Index} -> AST;
             Any -> Any
           end,
  release_memo(), Result.

-spec 'query'(input(), index()) -> parse_result().
'query'(Input, Index) ->
  p(Input, Index, 'query', fun(I,D) -> (fun 'expr'/2)(I,D) end, fun(Node, Idx) ->transform('query', Node, Idx) end).

-spec 'expr'(input(), index()) -> parse_result().
'expr'(Input, Index) ->
  p(Input, Index, 'expr', fun(I,D) -> (p_seq([p_label('lhs', fun 'expr_single'/2), p_label('rhs', p_zero_or_more(p_seq([p_optional(fun 'space'/2), fun 'op'/2, p_optional(fun 'space'/2), fun 'expr_single'/2])))]))(I,D) end, fun(Node, _Idx) ->
  Lhs = proplists:get_value(lhs, Node),
  Rhs = proplists:get_value(rhs, Node),
  Rhs2 = lists:flatmap(fun([_, Op, _, E]) -> [Op, E] end, Rhs),
  [Lhs | Rhs2]
 end).

-spec 'expr_single'(input(), index()) -> parse_result().
'expr_single'(Input, Index) ->
  p(Input, Index, 'expr_single', fun(I,D) -> (p_choose([fun 'array'/2, fun 'braced'/2, fun 'function'/2, fun 'literal'/2, fun 'path'/2]))(I,D) end, fun(Node, Idx) ->transform('expr_single', Node, Idx) end).

-spec 'braced'(input(), index()) -> parse_result().
'braced'(Input, Index) ->
  p(Input, Index, 'braced', fun(I,D) -> (p_seq([p_string(<<"(">>), p_optional(fun 'space'/2), p_label('e', fun 'expr'/2), p_optional(fun 'space'/2), p_string(<<")">>)]))(I,D) end, fun(Node, _Idx) ->
    proplists:get_value(e, Node)
   end).

-spec 'function'(input(), index()) -> parse_result().
'function'(Input, Index) ->
  p(Input, Index, 'function', fun(I,D) -> (p_seq([p_label('name', fun 'ident'/2), p_string(<<"(">>), p_optional(fun 'space'/2), p_label('args', p_optional(fun 'function_args'/2)), p_optional(fun 'space'/2), p_string(<<")">>)]))(I,D) end, fun(Node, _Idx) ->
  Name = proplists:get_value(name, Node),
  Args = proplists:get_value(args, Node),
  {function, Name, Args}
   end).

-spec 'function_args'(input(), index()) -> parse_result().
'function_args'(Input, Index) ->
  p(Input, Index, 'function_args', fun(I,D) -> (p_seq([p_label('head', p_zero_or_more(p_seq([fun 'expr'/2, p_optional(fun 'space'/2), p_string(<<",">>), p_optional(fun 'space'/2)]))), p_label('tail', fun 'expr'/2)]))(I,D) end, fun(Node, _Idx) ->
  Head = lists:flatmap(fun([E, _, _, _]) -> E end, proplists:get_value(head, Node)),
  Tail = proplists:get_value(tail, Node),
  lists:append(Head, Tail)
   end).

-spec 'op'(input(), index()) -> parse_result().
'op'(Input, Index) ->
  p(Input, Index, 'op', fun(I,D) -> (p_choose([fun 'op_and'/2, fun 'op_or'/2, fun 'op_eq'/2, fun 'op_neq'/2, fun 'op_concat'/2, fun 'op_gte'/2, fun 'op_gt'/2, fun 'op_lte'/2, fun 'op_lt'/2, fun 'op_in'/2, fun 'op_mul'/2, fun 'op_div'/2, fun 'op_add'/2, fun 'op_sub'/2]))(I,D) end, fun(Node, Idx) ->transform('op', Node, Idx) end).

-spec 'op_mul'(input(), index()) -> parse_result().
'op_mul'(Input, Index) ->
  p(Input, Index, 'op_mul', fun(I,D) -> (p_choose([p_string(<<"*">>), p_string(<<"times">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '*', left, 8} end).

-spec 'op_div'(input(), index()) -> parse_result().
'op_div'(Input, Index) ->
  p(Input, Index, 'op_div', fun(I,D) -> (p_choose([p_string(<<"\/">>), p_string(<<"div">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '/', left, 8} end).

-spec 'op_add'(input(), index()) -> parse_result().
'op_add'(Input, Index) ->
  p(Input, Index, 'op_add', fun(I,D) -> (p_choose([p_string(<<"+">>), p_string(<<"plus">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '+', left, 7} end).

-spec 'op_sub'(input(), index()) -> parse_result().
'op_sub'(Input, Index) ->
  p(Input, Index, 'op_sub', fun(I,D) -> (p_choose([p_string(<<"-">>), p_string(<<"minus">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '-', left, 7} end).

-spec 'op_concat'(input(), index()) -> parse_result().
'op_concat'(Input, Index) ->
  p(Input, Index, 'op_concat', fun(I,D) -> (p_choose([p_string(<<"<>">>), p_string(<<"concat">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '<>', right, 6} end).

-spec 'op_in'(input(), index()) -> parse_result().
'op_in'(Input, Index) ->
  p(Input, Index, 'op_in', fun(I,D) -> (p_string(<<"in">>))(I,D) end, fun(_Node, _Idx) ->{op, in, left, 5} end).

-spec 'op_gt'(input(), index()) -> parse_result().
'op_gt'(Input, Index) ->
  p(Input, Index, 'op_gt', fun(I,D) -> (p_choose([p_string(<<">">>), p_string(<<"gt">>), p_string(<<"greater_than">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '>', left, 4} end).

-spec 'op_gte'(input(), index()) -> parse_result().
'op_gte'(Input, Index) ->
  p(Input, Index, 'op_gte', fun(I,D) -> (p_choose([p_string(<<">=">>), p_string(<<"gte">>), p_string(<<"greater_than_or_equal">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '>=', left, 4} end).

-spec 'op_lt'(input(), index()) -> parse_result().
'op_lt'(Input, Index) ->
  p(Input, Index, 'op_lt', fun(I,D) -> (p_choose([p_string(<<"<">>), p_string(<<"lt">>), p_string(<<"less_than">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '<', left, 4} end).

-spec 'op_lte'(input(), index()) -> parse_result().
'op_lte'(Input, Index) ->
  p(Input, Index, 'op_lte', fun(I,D) -> (p_choose([p_string(<<"<=">>), p_string(<<"lte">>), p_string(<<"less_than_or_equal">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '<=', left, 4} end).

-spec 'op_eq'(input(), index()) -> parse_result().
'op_eq'(Input, Index) ->
  p(Input, Index, 'op_eq', fun(I,D) -> (p_choose([p_string(<<"==">>), p_string(<<"eq">>), p_string(<<"equals">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '==', left, 3} end).

-spec 'op_neq'(input(), index()) -> parse_result().
'op_neq'(Input, Index) ->
  p(Input, Index, 'op_neq', fun(I,D) -> (p_choose([p_string(<<"!=">>), p_string(<<"not_eq">>), p_string(<<"not_equals">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '!=', left, 3} end).

-spec 'op_and'(input(), index()) -> parse_result().
'op_and'(Input, Index) ->
  p(Input, Index, 'op_and', fun(I,D) -> (p_choose([p_string(<<"&&">>), p_string(<<"and">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '&&', left, 2} end).

-spec 'op_or'(input(), index()) -> parse_result().
'op_or'(Input, Index) ->
  p(Input, Index, 'op_or', fun(I,D) -> (p_choose([p_string(<<"||">>), p_string(<<"or">>)]))(I,D) end, fun(_Node, _Idx) ->{op, '||', left, 1} end).

-spec 'path'(input(), index()) -> parse_result().
'path'(Input, Index) ->
  p(Input, Index, 'path', fun(I,D) -> (p_seq([p_label('head', fun 'ident'/2), p_label('tail', p_zero_or_more(p_seq([p_string(<<".">>), fun 'path_element'/2])))]))(I,D) end, fun(Node, _Idx) ->
    Head = proplists:get_value(head, Node),
    Tail = lists:map(fun([_, E]) -> E end, proplists:get_value(tail, Node)),
    {path, [Head | Tail]}
   end).

-spec 'path_element'(input(), index()) -> parse_result().
'path_element'(Input, Index) ->
  p(Input, Index, 'path_element', fun(I,D) -> (fun 'ident'/2)(I,D) end, fun(Node, Idx) ->transform('path_element', Node, Idx) end).

-spec 'array'(input(), index()) -> parse_result().
'array'(Input, Index) ->
  p(Input, Index, 'array', fun(I,D) -> (p_seq([p_string(<<"[">>), p_optional(fun 'space'/2), p_label('elements', p_optional(fun 'array_elements'/2)), p_optional(fun 'space'/2), p_string(<<"]">>)]))(I,D) end, fun(Node, _Idx) ->
    proplists:get_value(elements, Node)
   end).

-spec 'array_elements'(input(), index()) -> parse_result().
'array_elements'(Input, Index) ->
  p(Input, Index, 'array_elements', fun(I,D) -> (p_seq([p_label('head', p_zero_or_more(p_seq([fun 'expr'/2, p_optional(fun 'space'/2), p_string(<<",">>), p_optional(fun 'space'/2)]))), p_label('tail', fun 'expr'/2)]))(I,D) end, fun(Node, _Idx) ->
   Head = lists:flatmap(fun([E, _, _, _]) -> E end, proplists:get_value(head, Node)),
   Tail = proplists:get_value(tail, Node),
   {array, lists:append(Head, Tail)}
   end).

-spec 'literal'(input(), index()) -> parse_result().
'literal'(Input, Index) ->
  p(Input, Index, 'literal', fun(I,D) -> (p_choose([fun 'boolean'/2, fun 'float'/2, fun 'integer'/2, fun 'string'/2]))(I,D) end, fun(Node, Idx) ->transform('literal', Node, Idx) end).

-spec 'boolean'(input(), index()) -> parse_result().
'boolean'(Input, Index) ->
  p(Input, Index, 'boolean', fun(I,D) -> (p_choose([fun 'boolean_true'/2, fun 'boolean_false'/2]))(I,D) end, fun(Node, Idx) ->transform('boolean', Node, Idx) end).

-spec 'boolean_true'(input(), index()) -> parse_result().
'boolean_true'(Input, Index) ->
  p(Input, Index, 'boolean_true', fun(I,D) -> (p_string(<<"true">>))(I,D) end, fun(_Node, _Idx) ->{boolean, true} end).

-spec 'boolean_false'(input(), index()) -> parse_result().
'boolean_false'(Input, Index) ->
  p(Input, Index, 'boolean_false', fun(I,D) -> (p_string(<<"false">>))(I,D) end, fun(_Node, _Idx) ->{boolean, false} end).

-spec 'integer'(input(), index()) -> parse_result().
'integer'(Input, Index) ->
  p(Input, Index, 'integer', fun(I,D) -> (p_seq([p_optional(p_string(<<"-">>)), p_choose([p_string(<<"0">>), p_seq([p_charclass(<<"[1-9]">>), p_zero_or_more(p_charclass(<<"[0-9]">>))])])]))(I,D) end, fun(Node, _Idx) ->
    Number = iolist_to_binary(Node),
    {integer, binary_to_integer(Number)}
   end).

-spec 'float'(input(), index()) -> parse_result().
'float'(Input, Index) ->
  p(Input, Index, 'float', fun(I,D) -> (p_seq([p_optional(p_string(<<"-">>)), p_seq([p_one_or_more(p_charclass(<<"[0-9]">>)), p_string(<<".">>), p_one_or_more(p_charclass(<<"[0-9]">>))])]))(I,D) end, fun(Node, _Idx) ->
    Number = iolist_to_binary(Node),
    {float, binary_to_float(Number)}
   end).

-spec 'string'(input(), index()) -> parse_result().
'string'(Input, Index) ->
  p(Input, Index, 'string', fun(I,D) -> (p_choose([fun 'string_double'/2, fun 'string_single'/2]))(I,D) end, fun(Node, Idx) ->transform('string', Node, Idx) end).

-spec 'string_double'(input(), index()) -> parse_result().
'string_double'(Input, Index) ->
  p(Input, Index, 'string_double', fun(I,D) -> (p_seq([p_string(<<"\"">>), p_label('chars', p_zero_or_more(p_seq([p_not(p_string(<<"\"">>)), p_choose([p_string(<<"\\\\">>), p_string(<<"\\\"">>), p_anything()])]))), p_string(<<"\"">>)]))(I,D) end, fun(Node, _Idx) ->{string, iolist_to_binary(proplists:get_value(chars, Node))} end).

-spec 'string_single'(input(), index()) -> parse_result().
'string_single'(Input, Index) ->
  p(Input, Index, 'string_single', fun(I,D) -> (p_seq([p_string(<<"\'">>), p_label('chars', p_zero_or_more(p_seq([p_not(p_string(<<"\'">>)), p_choose([p_string(<<"\\\\">>), p_string(<<"\\\'">>), p_anything()])]))), p_string(<<"\'">>)]))(I,D) end, fun(Node, _Idx) ->{string, iolist_to_binary(proplists:get_value(chars, Node))} end).

-spec 'ident'(input(), index()) -> parse_result().
'ident'(Input, Index) ->
  p(Input, Index, 'ident', fun(I,D) -> (p_seq([p_charclass(<<"[a-zA-Z_]">>), p_zero_or_more(p_charclass(<<"[a-zA-Z0-9_]">>))]))(I,D) end, fun(Node, _Idx) ->{ident, iolist_to_binary(Node)} end).

-spec 'space'(input(), index()) -> parse_result().
'space'(Input, Index) ->
  p(Input, Index, 'space', fun(I,D) -> (p_zero_or_more(p_charclass(<<"[\s\t\n\s\r]">>)))(I,D) end, fun(Node, _Idx) ->Node end).


transform(_,Node,_Index) -> Node.
-file("peg_includes.hrl", 1).
-type index() :: {{line, pos_integer()}, {column, pos_integer()}}.
-type input() :: binary().
-type parse_failure() :: {fail, term()}.
-type parse_success() :: {term(), input(), index()}.
-type parse_result() :: parse_failure() | parse_success().
-type parse_fun() :: fun((input(), index()) -> parse_result()).
-type xform_fun() :: fun((input(), index()) -> term()).

-spec p(input(), index(), atom(), parse_fun(), xform_fun()) -> parse_result().
p(Inp, StartIndex, Name, ParseFun, TransformFun) ->
  case get_memo(StartIndex, Name) of      % See if the current reduction is memoized
    {ok, Memo} -> %Memo;                     % If it is, return the stored result
      Memo;
    _ ->                                        % If not, attempt to parse
      Result = case ParseFun(Inp, StartIndex) of
        {fail,_} = Failure ->                       % If it fails, memoize the failure
          Failure;
        {Match, InpRem, NewIndex} ->               % If it passes, transform and memoize the result.
          Transformed = TransformFun(Match, StartIndex),
          {Transformed, InpRem, NewIndex}
      end,
      memoize(StartIndex, Name, Result),
      Result
  end.

-spec setup_memo() -> ets:tid().
setup_memo() ->
  put({parse_memo_table, ?MODULE}, ets:new(?MODULE, [set])).

-spec release_memo() -> true.
release_memo() ->
  ets:delete(memo_table_name()).

-spec memoize(index(), atom(), parse_result()) -> true.
memoize(Index, Name, Result) ->
  Memo = case ets:lookup(memo_table_name(), Index) of
              [] -> [];
              [{Index, Plist}] -> Plist
         end,
  ets:insert(memo_table_name(), {Index, [{Name, Result}|Memo]}).

-spec get_memo(index(), atom()) -> {ok, term()} | {error, not_found}.
get_memo(Index, Name) ->
  case ets:lookup(memo_table_name(), Index) of
    [] -> {error, not_found};
    [{Index, Plist}] ->
      case proplists:lookup(Name, Plist) of
        {Name, Result}  -> {ok, Result};
        _  -> {error, not_found}
      end
    end.

-spec memo_table_name() -> ets:tid().
memo_table_name() ->
    get({parse_memo_table, ?MODULE}).

-ifdef(p_eof).
-spec p_eof() -> parse_fun().
p_eof() ->
  fun(<<>>, Index) -> {eof, [], Index};
     (_, Index) -> {fail, {expected, eof, Index}} end.
-endif.

-ifdef(p_optional).
-spec p_optional(parse_fun()) -> parse_fun().
p_optional(P) ->
  fun(Input, Index) ->
      case P(Input, Index) of
        {fail,_} -> {[], Input, Index};
        {_, _, _} = Success -> Success
      end
  end.
-endif.

-ifdef(p_not).
-spec p_not(parse_fun()) -> parse_fun().
p_not(P) ->
  fun(Input, Index)->
      case P(Input,Index) of
        {fail,_} ->
          {[], Input, Index};
        {Result, _, _} -> {fail, {expected, {no_match, Result},Index}}
      end
  end.
-endif.

-ifdef(p_assert).
-spec p_assert(parse_fun()) -> parse_fun().
p_assert(P) ->
  fun(Input,Index) ->
      case P(Input,Index) of
        {fail,_} = Failure-> Failure;
        _ -> {[], Input, Index}
      end
  end.
-endif.

-ifdef(p_seq).
-spec p_seq([parse_fun()]) -> parse_fun().
p_seq(P) ->
  fun(Input, Index) ->
      p_all(P, Input, Index, [])
  end.

-spec p_all([parse_fun()], input(), index(), [term()]) -> parse_result().
p_all([], Inp, Index, Accum ) -> {lists:reverse( Accum ), Inp, Index};
p_all([P|Parsers], Inp, Index, Accum) ->
  case P(Inp, Index) of
    {fail, _} = Failure -> Failure;
    {Result, InpRem, NewIndex} -> p_all(Parsers, InpRem, NewIndex, [Result|Accum])
  end.
-endif.

-ifdef(p_choose).
-spec p_choose([parse_fun()]) -> parse_fun().
p_choose(Parsers) ->
  fun(Input, Index) ->
      p_attempt(Parsers, Input, Index, none)
  end.

-spec p_attempt([parse_fun()], input(), index(), none | parse_failure()) -> parse_result().
p_attempt([], _Input, _Index, Failure) -> Failure;
p_attempt([P|Parsers], Input, Index, FirstFailure)->
  case P(Input, Index) of
    {fail, _} = Failure ->
      case FirstFailure of
        none -> p_attempt(Parsers, Input, Index, Failure);
        _ -> p_attempt(Parsers, Input, Index, FirstFailure)
      end;
    Result -> Result
  end.
-endif.

-ifdef(p_zero_or_more).
-spec p_zero_or_more(parse_fun()) -> parse_fun().
p_zero_or_more(P) ->
  fun(Input, Index) ->
      p_scan(P, Input, Index, [])
  end.
-endif.

-ifdef(p_one_or_more).
-spec p_one_or_more(parse_fun()) -> parse_fun().
p_one_or_more(P) ->
  fun(Input, Index)->
      Result = p_scan(P, Input, Index, []),
      case Result of
        {[_|_], _, _} ->
          Result;
        _ ->
          {fail, {expected, Failure, _}} = P(Input,Index),
          {fail, {expected, {at_least_one, Failure}, Index}}
      end
  end.
-endif.

-ifdef(p_label).
-spec p_label(atom(), parse_fun()) -> parse_fun().
p_label(Tag, P) ->
  fun(Input, Index) ->
      case P(Input, Index) of
        {fail,_} = Failure ->
           Failure;
        {Result, InpRem, NewIndex} ->
          {{Tag, Result}, InpRem, NewIndex}
      end
  end.
-endif.

-ifdef(p_scan).
-spec p_scan(parse_fun(), input(), index(), [term()]) -> {[term()], input(), index()}.
p_scan(_, <<>>, Index, Accum) -> {lists:reverse(Accum), <<>>, Index};
p_scan(P, Inp, Index, Accum) ->
  case P(Inp, Index) of
    {fail,_} -> {lists:reverse(Accum), Inp, Index};
    {Result, InpRem, NewIndex} -> p_scan(P, InpRem, NewIndex, [Result | Accum])
  end.
-endif.

-ifdef(p_string).
-spec p_string(binary()) -> parse_fun().
p_string(S) ->
    Length = erlang:byte_size(S),
    fun(Input, Index) ->
      try
          <<S:Length/binary, Rest/binary>> = Input,
          {S, Rest, p_advance_index(S, Index)}
      catch
          error:{badmatch,_} -> {fail, {expected, {string, S}, Index}}
      end
    end.
-endif.

-ifdef(p_anything).
-spec p_anything() -> parse_fun().
p_anything() ->
  fun(<<>>, Index) -> {fail, {expected, any_character, Index}};
     (Input, Index) when is_binary(Input) ->
          <<C/utf8, Rest/binary>> = Input,
          {<<C/utf8>>, Rest, p_advance_index(<<C/utf8>>, Index)}
  end.
-endif.

-ifdef(p_charclass).
-spec p_charclass(string() | binary()) -> parse_fun().
p_charclass(Class) ->
    {ok, RE} = re:compile(Class, [unicode, dotall]),
    fun(Inp, Index) ->
            case re:run(Inp, RE, [anchored]) of
                {match, [{0, Length}|_]} ->
                    {Head, Tail} = erlang:split_binary(Inp, Length),
                    {Head, Tail, p_advance_index(Head, Index)};
                _ -> {fail, {expected, {character_class, binary_to_list(Class)}, Index}}
            end
    end.
-endif.

-ifdef(p_regexp).
-spec p_regexp(binary()) -> parse_fun().
p_regexp(Regexp) ->
    {ok, RE} = re:compile(Regexp, [unicode, dotall, anchored]),
    fun(Inp, Index) ->
        case re:run(Inp, RE) of
            {match, [{0, Length}|_]} ->
                {Head, Tail} = erlang:split_binary(Inp, Length),
                {Head, Tail, p_advance_index(Head, Index)};
            _ -> {fail, {expected, {regexp, binary_to_list(Regexp)}, Index}}
        end
    end.
-endif.

-ifdef(line).
-spec line(index() | term()) -> pos_integer() | undefined.
line({{line,L},_}) -> L;
line(_) -> undefined.
-endif.

-ifdef(column).
-spec column(index() | term()) -> pos_integer() | undefined.
column({_,{column,C}}) -> C;
column(_) -> undefined.
-endif.

-spec p_advance_index(input() | unicode:charlist() | pos_integer(), index()) -> index().
p_advance_index(MatchedInput, Index) when is_list(MatchedInput) orelse is_binary(MatchedInput)-> % strings
  lists:foldl(fun p_advance_index/2, Index, unicode:characters_to_list(MatchedInput));
p_advance_index(MatchedInput, Index) when is_integer(MatchedInput) -> % single characters
  {{line, Line}, {column, Col}} = Index,
  case MatchedInput of
    $\n -> {{line, Line+1}, {column, 1}};
    _ -> {{line, Line}, {column, Col+1}}
  end.
