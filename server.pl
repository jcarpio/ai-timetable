#!/usr/bin/env swipl

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Simsttab -- Simplistic school time tabler
   Copyright (C) 2005-2022 Markus Triska triska@metalevel.at
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or 
   (at your option) any later version.
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
   For more information about this program, visit:
          https://www.metalevel.at/simsttab/
          ==================================
   Tested with Scryer Prolog.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

% :- load_files('req3.pl').

:- use_module(library(clpfd)).
:- use_module(library(persistency)).
:- use_module(library(reif)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_server_files)).
:- use_module(library(http/http_parameters)).

/*
:- dynamic(class_subject_teacher_times/4).
:- dynamic(coupling/4).
:- dynamic(teacher_freeday/2).
:- dynamic(slots_per_day/1).
:- dynamic(slots_per_week/1).
:- dynamic(class_freeslot/2).
:- dynamic(room_alloc/4)
*/

:- dynamic class_subject_teacher_times/4.
:- dynamic room_ingles/4.
:- dynamic coupling/4.
:- dynamic teacher_freeday/2.
:- dynamic slots_per_day/1.
:- dynamic slots_couplings/2.
:- dynamic slots_per_week/1.
:- dynamic class_freeslot/2.
:- dynamic room_alloc/4.


:- discontiguous class_subject_teacher_times/4.
:- discontiguous class_freeslot/2.


:- initialization main.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                   Posting constraints
   The most important data structure in this CSP are pairs of the form
      Req-Vs
   where Req is a term of the form req(C,S,T,N) (see below), and Vs is
   a list of length N. The elements of Vs are finite domain variables
   that denote the *time slots* of the scheduled lessons of Req. We
   call this list of Req-Vs pairs the requirements.
   To break symmetry, the elements of Vs are constrained to be
   strictly ascending (it follows that they are all_different/1).
   Further, the time slots of each teacher are constrained to be
   all_different/1.
   For each requirement, the time slots divided by slots_per_day are
   constrained to be strictly ascending to enforce distinct days,
   except for coupled lessons.
   The time slots of each class, and of lessons occupying the same
   room, are constrained to be all_different/1.
   Labeling is performed on all slot variables.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% Asigna el handler de la raíz `/` para servir `index.html`
:- http_handler(root(.), serve_homepage, []).

%% Predicado para servir la página principal desde un archivo
serve_homepage(Request) :-
    http_reply_file('index.html', [], Request).

main :- 
  http_server(http_dispatch, [port(8080)]),
  thread_get_message(quit).

classes(Classes) :-
       setof(C, S^N^T^class_subject_teacher_times(C,S,T,N), Classes).
        
subject_room(Subjects) :-
       findall(C-S, room_alloc(_A,C,S,_N), Subjects0),
        sort(Subjects0, Subjects).

subject_room_ingles(SubjectsIng) :-
       findall(C-S, room_ingles(_A,C,S,_N), SubjectsIng0),
        sort(SubjectsIng0, SubjectsIng).
		
turno_Ingles(Tingles):-
		findall(C, room_ingles(_A,C,_S,_N), SubjectsIng0),
        sort(SubjectsIng0, Tingles).
            
teachers(Teachers) :-
        setof(T, C^S^N^class_subject_teacher_times(C,S,T,N), Teachers).
            
rooms(Rooms) :-
        findall(Room, room_alloc(Room,_C,_S,_Slot), Rooms0),
        sort(Rooms0, Rooms).
            
requirements(Rs) :-
        Goal = class_subject_teacher_times(Class,Subject,Teacher,Number),
        setof(req(Class,Subject,Teacher,Number), Goal, Rs0),
        maplist(req_with_slots, Rs0, Rs).

/*
requirements_room(Ra) tiene el mismo funcionamiento que requirements(Rs) con la salvedad de que actua sobre las room_alloc. 1,2,3,15,22
*/

requirements_room(Ralloc):-
            Goal = room_alloc(Aula , Class , Subject , Numero) ,
            findall(rom(Aula,Class,Subject,Numero), Goal, Rs0),
            sort(Rs0, Rs),
            maplist(room_with_slots, Rs, Ralloc).

req_with_slots(R, R-Slots) :- R = req(_,_,_,N), length(Slots, N).

requirements_eng(Ringles):-
            Goal = room_ingles(Aula , Class , Subject , Numero) ,
            findall(rIng(Aula,Class,Subject,Numero), Goal, Rs0),
            sort(Rs0, Rs),
            maplist(room_ingles_with_slots, Rs, Ringles).

room_ingles_with_slots(R, R-Slots) :- R = rIng(_,_,_,N), length(Slots, N).

/*
creamos una lista de un solo elemento detras de rom -> rom(Aula,Class,Subject,Lesson)-[_]
*/
room_with_slots(R, R-Slots) :- R = rom(_,_,_,_), length(Slots, 1).

pairs_slots(Ps, Vs) :-
        pairs_values(Ps, Vs0),
        append(Vs0, Vs).
                  
sameroom_var(Reqs, r(Class,Subject,Lesson), Var) :-
        memberchk(req(Class,Subject,_Teacher,_Num)-Slots, Reqs),
        nth0(Lesson, Slots, Var).
            
strictly_ascending(Ls) :- chain(Ls, #<).

constrain_room(Reqs, Room) :-
        findall(r(Class,Subj,Less), room_alloc(Room,Class,Subj,Less), RReqs),
        maplist(sameroom_var(Reqs), RReqs, Roomvars),
        all_different(Roomvars).

slot_quotient(S, Q) :-
        slots_per_day(SPD),
        Q #= S // SPD.

/*          
without_([], _, Es) --> seq(Es).
without_([W|Ws], Pos0, [E|Es]) -->
        { Pos #= Pos0 + 1,
          zcompare(R, W, Pos0) },
        without_at_pos0(R, E, [W|Ws], Ws1),
        without_(Ws1, Pos, Es).
without_at_pos0(=, _, [_|Ws], Ws) --> [].
without_at_pos0(>, E, Ws0, Ws0) --> [E].
*/

% list_without_nths(Es0, Ws, Es) :-
%        phrase(without_(Ws, 0, Es0), Es).

 list_without_nths(Lista, [], Lista).
 
 list_without_nths(Lista, [Cab|Resto], R2):-
   list_without_nths(Lista, Resto, R), elimina_pos(R, Cab, R2).
   
/*  
 elimina_pos(+Lista, +Pos, -R)
   es cierto si R unifica con una lista que contiene los elementos
   de Lista exceptuando el que ocupa la posición Pos. Los
   valores de posiciones empiezan en 0.
*/

 elimina_pos([], _, []).
 
 elimina_pos([_|Resto], 0, Resto).
 
 elimina_pos([Cab|Resto], Pos, [Cab|R]):- Pos > 0, Pos2 #= Pos - 1,
   elimina_pos(Resto, Pos2, R).
            
%:- list_without_nths("abcd", [3], "abc").
%:- list_without_nths("abcd", [1,2], "ad").           
            
            
requirements_variables(Rs, Ralloc,Ringles,Vars) :-
        requirements(Rs),
            requirements_room(Ralloc),
            requirements_eng(Ringles),
        pairs_slots(Rs, Vars),
        slots_per_week(SPW),
        Max #= SPW - 1,
        Vars ins 0..Max,
        maplist(constrain_subject, Rs),
        classes(Classes),
        teachers(Teachers),
        rooms(Rooms),
            subject_room(S),
            subject_room_ingles(S1),
        maplist(constrain_teacher(Rs), Teachers),
        maplist(constrain_class(Rs), Classes),
        maplist(constrain_room(Rs), Rooms),
        maplist(constrain_room_alloc(Rs,Ralloc) ,S),
        maplist(constrain_room_ingles(Rs,Ringles),S1).

constrain_class(Rs, Class) :-
        tfilter(class_req(Class), Rs, Sub),
        pairs_slots(Sub, Vs),
        all_different(Vs),
        findall(S, class_freeslot(Class,S), Frees),
        maplist(all_diff_from(Vs), Frees).
            
/*
Restricciones para que el valor dentro la lista rom y req en el Lesson especifico de room_alloc. req(_,_,_,_)-[_A] , rom(_,_,_,_)-[_B] _A #=_B
*/
constrain_room_alloc(Rs ,Ralloc, Class-Subject):-
            tfilter(class_req(Class), Rs, Sub),
            tfilter(subject_req(Subject), Sub, Sub1),
            
            tfilter(class_room_alloc(Class), Ralloc, Sub2),
            tfilter(subject_room_alloc(Subject), Sub2, Sub3),
            maplist(objetive(Sub1) , Sub3).

constrain_room_ingles(Rs ,Ringles, Class-Subject):-
            tfilter(class_req(Class), Rs, Sub),
            tfilter(subject_req(Subject), Sub, Sub1),
            
            tfilter(class_room_ingles(Class), Ringles, Sub2),
            tfilter(subject_room_ingles(Subject), Sub2, Sub3),
            objetiveIngles(Sub1 , Sub3).
	

%%% fallo aqui , averiguar	
objetiveIngles([req(_,_,_,_)-[]] , _ ).
objetiveIngles([req(_,_,_,_)-[Cab1|Resto1]],[rIng(_,_,_,N)-[Cab2|Resto2]]):-
            N > 0 , N2 is N-1,Cab1 #= Cab2, 
            objetiveIngles([req(_,_,_,_)-Resto1],[rIng(_,_,_,N2)-Resto2]).

			
/*
req(_,_,_,_)-[_A] , rom(_,_,_,_)-[_B] _A #=_B

en el caso de que Lesson vale 0, hacemos la restriccion y cuando es >0 seguimos buscando.
*/
objetive([] , _ ).
objetive([req(_,_,_,_)-[Cab1|_]|_] ,rom(_,_,_,N)-[Cab|_]):-
            N = 0 , Cab1 #= Cab.
objetive([req(_,_,_,_)-[_|Resto]|_],rom(_,_,_,N)-[Cab|_]):-
            N > 0 , Cab2 is N-1,
            objetive([req(_,_,_,_)-Resto],rom(_,_,_,Cab2)-[Cab]).
            

all_diff_from(Vs, F) :- maplist(#\=(F), Vs).

constrain_subject(req(Class,Subj,_Teacher,_Num)-Slots) :-
        strictly_ascending(Slots), % break symmetry
        maplist(slot_quotient, Slots, Qs0),
        findall(F-S, coupling(Class,Subj,F,S), Cs),
        maplist(slots_couplings(Slots), Cs),
        pairs_values(Cs, Seconds0),
        sort(Seconds0, Seconds),
        list_without_nths(Qs0, Seconds, Qs),
        strictly_ascending(Qs).     
            
slots_couplings(Slots, F-S) :-
        nth0(F, Slots, S1),
        nth0(S, Slots, S2),
        S2 #= S1 + 1.         

constrain_teacher(Rs, Teacher) :-
        tfilter(teacher_req(Teacher), Rs, Sub),
        pairs_slots(Sub, Vs),
        all_different(Vs),
        findall(F, teacher_freeday(Teacher, F), Fs),
        maplist(slot_quotient, Vs, Qs),
        maplist(all_diff_from(Qs), Fs).

teacher_req(T0, req(_C,_S,T1,_N)-_, T) :- =(T0,T1,T).
class_req(C0, req(C1,_S,_T,_N)-_, T) :- =(C0, C1, T).
subject_req(C0, req(_C,C1,_T,_N)-_, T) :- =(C0, C1, T).
class_room(C0, req(_A,C1,_S,_N)-_, T) :- =(C0, C1, T).
room_req(C0, rom(C1,_A,_S,_N)-_, T) :- =(C0, C1, T).

class_room_alloc(C0, rom(_A,C1,_S,_N)-_, T) :- =(C0, C1, T).
class_room_ingles(C0, rIng(_A,C1,_S,_N)-_, T) :- =(C0, C1, T).
subject_room_ingles(C0, rIng(_A,_C,C1,_N)-_, T) :- =(C0, C1, T).
subject_room_alloc(C0, rom(_A,_C,C1,_N)-_, T) :- =(C0, C1, T).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Relate teachers and classes to list of days.
   Each day is a list of subjects (for classes), and a list of
   class/subject terms (for teachers). The predicate days_variables/2
   yields a list of days with the right dimensions, where each element
   is a free variable.
   We use the atom 'free' to denote a free slot, and the compound terms
   class_subject(C, S) and subject(S) to denote classes/subjects.
   This clean symbolic distinction is used to support subjects
   that are called 'free', and to improve generality and efficiency.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

days_variables(Days, Vs) :-
        slots_per_week(SPW),
        slots_per_day(SPD),
        NumDays #= SPW // SPD,
        length(Days, NumDays),
        length(Day, SPD),
        maplist(same_length(Day), Days),
        append(Days, Vs).
            
class_days(Rs,Rm, Class, Days) :-
        days_variables(Days, Vs),
        tfilter(class_req(Class), Rs, Sub),
            tfilter(class_room_alloc(Class), Rm, Sub1),
        foldl(v(Sub,Sub1), Vs, 0, _).
            
/* room_days(Rm , Class ,Vs):-
        tfilter(class_room_alloc(Class), Rm, Sub),
        foldl(v_room(Sub), Vs, 0, _).
            
v_room(Rm, V, N0, N) :-
            (member(rom(Aula,_,Subject,_)-Times, Rm),member(N0, Times) -> V = subject(Aula, Subject) ;
            N1 =1),
        N #= N0 + 1.*/

v(Rs,Rm,V, N0, N) :-
        (   member(rom(Aula,_,Subject,_)-Times, Rm),member(N0, Times) -> V = class_subject(Aula, Subject);
                  member(req(_,Subject,_,_)-Times, Rs),member(N0, Times) -> V = subject(Subject);
                  V = free
        ),
        N #= N0 + 1.

teacher_days(Rs, Teacher, Days) :-
        days_variables(Days, Vs),
        tfilter(teacher_req(Teacher), Rs, Sub),
        foldl(v_teacher(Sub), Vs, 0, _).

v_teacher(Rs, V, N0, N) :-
        (   member(req(C,Subj,_,_)-Times, Rs),
            member(N0, Times) -> V = class_subject(C, Subj)
        ;   V = free
        ),
        N #= N0 + 1.
		
rooms_days(Rs, Aulas, Days):-
		days_variables(Days, Vs),
		tfilter(room_req(Aulas), Rs, Sub),
		foldl(v_rooms(Sub), Vs, 0, _).
		
v_rooms(Rs, V, N0, N) :-
		(   member(rom(_,C,Subj,_)-Times, Rs),
            member(N0, Times) -> V = class_subject(C, Subj)
        ;   V = free
        ),
        N #= N0 + 1.
		
ingles_days(Rs, Class , Days):-
		days_variables(Days, Vs),
		tfilter(class_room_ingles(Class), Rs, Sub),
		foldl(v_ingles(Sub), Vs, 0, _).

v_ingles(Rs , V , N0 , N):-
		(   member(rIng(_,_,Subj,_)-Times, Rs),
            member(N0, Times) -> V = subject(Subj)
        ;   V = free
        ),
        N #= N0 + 1.
		
		
            
% requirements_variables(Rs, Vs), labeling([ff], Vs), class_days(Rs, '1a', Days), transpose(Days, DaysT).

print_classes(Rs,Rm) :-
        classes(Cs),
        format_classes(Cs, Rs,Rm).

format_classes([], _,_).
format_classes([Class|Classes], Rs , Rm):-
  class_days(Rs,Rm, Class, Days0),
  transpose(Days0, Days),
  format("<h2>Class: ~w</h2>~2n", [Class]),
  weekdays_header,
  align_rows(Days),
  format('</table></div>~2n', []),
  format_classes(Classes, Rs,Rm).
 
% [subject(mat), free, class_subject('1a', mat), free]
% [mat, '', '1a/mat', '']
 
align_rows([]):- format("\n\n\n",[]).
align_rows([R|Rs]):-
        align_row(R),
        align_rows(Rs).


align_row(Row):-
            translate_row(Row, R2),
            format("<tr><td>~w</td><td>~w</td><td>~w</td><td>~w</td><td>~w</td></tr>\n", R2).
 
weekdays_header :-
    format('<div class="table-responsive">'),
    format('<table class="table table-bordered table-striped table-hover">'),
    format('<thead style="background-color: #4CAF50; color: white; font-size: 18px;">'),  % Fondo verde y texto blanco
    format('<tr><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th></tr>'),
    format('</thead><tbody>\n').
    
translate_row([], []).
translate_row([subject(S)|Tail], [S|R]):-  
   translate_row(Tail, R).
translate_row([class_subject(C,S)|Tail], [C/S|R]):-  
   translate_row(Tail, R).
translate_row([free|Tail], ['&nbsp;'|R]):-  
   translate_row(Tail, R).


align(free):- format("~t~w~t~8+", ['']).
align(class_subject(C,S)):- format("~t~w~t~8+", [C/S]).           
align(subject(S)):- format("~t~w~t~8+", [S]).
align([E1,E2,E3,E4,E5]):- format("~t~w~t~8+~t~w~t~8+~t~w~t~8+~t~w~t~8+~t~w~t~8+", [E1,E2,E3,E4,E5]).

with_verbatim(T, verbatim(T)).

format_teachers([], _).
format_teachers([T|Ts], Rs):-
        teacher_days(Rs, T, Days0),
        transpose(Days0, Days),
        format("<h2>Teacher: ~w</h2>~2n", [T]),
        weekdays_header,
        align_rows(Days),
            format("</table></div>", []),
        format_teachers(Ts, Rs).
            
print_teachers(Rs) :-
        teachers(Ts),
        format_teachers(Ts, Rs).
		
print_room(Ralloc) :-
		rooms(Ro),
        format_rooms(Ro, Ralloc).
		
format_rooms([], _).
format_rooms([T|Ts], Rs):-
		rooms_days(Rs, T, Days0),
        transpose(Days0, Days),
        format("<h2>Aula: ~w</h2>~2n", [T]),
        weekdays_header,
        align_rows(Days),
            format("</table></div>", []),
        format_rooms(Ts, Rs).
		
print_ingles(Ringles) :-
		turno_Ingles(Ri),
        format_ingles(Ri, Ringles).
		
format_ingles([], _).
format_ingles([T|Ts], Rs):-
		ingles_days(Rs, T, Days0),
        transpose(Days0, Days),
        format("<h2>Class Ingles: ~w</h2>~2n", [T]),
        weekdays_header,
        align_rows(Days),
		format("</table></div>", []),
        format_ingles(Ts, Rs).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- http_handler(root(aitt), aitt, []).          % (1)

server(Port) :-                                 % (2)
        http_server(http_dispatch, [port(Port)]).


% Parsea la entrada del usuario y la almacena en la base de conocimiento
store_facts(UserInput) :-
    split_string(UserInput, "\r\n", '\r\n', R), 
    maplist(process_line, R).                 % Procesa cada línea

process_line(Line) :-
    trim_string(Line, Trimmed),   % Remove extra spaces
    Trimmed \= "",                % Ignore empty lines
    term_string(Term, Trimmed),   % Convert string to Prolog term
    assertz(Term).               % Store term in dynamic database
    % print(Term).

% split_string/4: Type error: `character_code' expected, found `message='slots_per_week(35).\r\nslots_per_day(7).\r\nclass_subject_teacher_times(\'1a\', math, t1, 5).\>
trim_string(String, Trimmed) :-
    string_codes(String, Codes),
    phrase(trim(Codes), TrimmedCodes),
    string_codes(Trimmed, TrimmedCodes).

trim([]) --> [].
trim([C|Cs]) --> { char_type(C, space) }, !, trim(Cs).
trim(Cs) --> trim_end(Cs).

trim_end([]) --> [].
trim_end([C|Cs]) --> [C], trim_end(Cs).
trim_end([C]) --> { \+ char_type(C, space) }.

aitt(Request) :-
   catch(
        (
          http_parameters(Request, [message(UserInput, [string])]),
          store_facts(UserInput), % Insertamos los hechos en la base de conocimiento
          format('Content-type: text/html~n~n'),
          format('<!DOCTYPE html>'),
          format('<html><head>'),
          format('<meta charset="utf-8">'),
          format('<meta name="viewport" content="width=device-width, initial-scale=1">'),
          format('<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css">'),
          format('<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.4/jquery.min.js"></script>'),
          format('<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js"></script>'),
          format('<style>
              body { font-family: Arial, sans-serif; margin: 20px; }
              h1 { text-align: center; margin-bottom: 20px; }
              .table-container { width: 80%%; margin: auto; }
              .table thead { background-color: #4CAF50; color: white; }
              .table tbody tr:nth-child(even) { background-color: #f2f2f2; }
              .table tbody tr:hover { background-color: #ddd; }
              td { text-align: center; font-weight: bold; padding: 10px; }
              th { padding: 12px; text-align: center; }
              .table-bordered th, .table-bordered td { border: 1px solid #ddd; }
          </style>'),
          format('</head><body>'),
          format('<h1>AI Timetable</h1>'),
          format('    <div class="container">~n', []),
          format('        <h3>Input Data</h3>~n', []),
          format('        <textarea readonly>~w</textarea>~n', [UserInput]),
          format('    </div>~n', []),
          format('<div class="table-container">'),
          requirements_variables(Rs,Ralloc,Ringles, Vs),
          labeling([ff], Vs),
          print_classes(Rs,Ralloc),
          print_teachers(Rs),
          print_room(Ralloc),
          print_ingles(Ringles),
          format('</div>'),
          format('</body></html>')
      ),
      Error,
        (   format('Content-type: text/plain~n~n'),
            format('Internal Server Error: ~w~n', [Error])
        )
    ).
            
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   ?- server(8080).
   
   ?- requirements_variables(Rs,Ra, Vs),labeling([ff], Vs),print_classes(Rs).
   ?- requirements_variables(Rs,Ralloc,Ringles, Vs),labeling([ff], Vs),print_room(Ralloc).
   %@ Class: 1a
   %@
   %@   Mon     Tue     Wed     Thu     Fri
   %@ ========================================
   %@   mat     mat     mat     mat     mat
   %@   eng     eng     eng
   %@    h       h
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
