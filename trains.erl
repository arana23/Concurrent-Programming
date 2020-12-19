-module(train).
-compile(export_all).

start () ->
  register ( loading_machine , spawn ( fun loadingMachine /0)) ,
  register ( control_center , spawn (? MODULE , controlCenterLoop ,[1 ,1])) ,
  [ spawn (? MODULE , passengerTrain ,[0]) || _ <- lists : seq (1 ,10) ],
  [ spawn (? MODULE , passengerTrain ,[1]) || _ <- lists : seq (1 ,10) ],
  [ spawn (? MODULE , freightTrain ,[0]) || _ <- lists : seq (1 ,5) ],
  [ spawn (? MODULE , freightTrain ,[1]) || _ <- lists : seq (1 ,5) ].

passengerTrain ( Direction ) ->
  acquireTrack ( Direction ) ,
  timer : sleep ( rand : uniform (1000)) , % passengers get on/off
  releaseTrack ( Direction ).

freightTrain ( _Direction ) ->
  acquireTrack (0) ,
  acquireTrack (1) ,
  waitForLoadingMachine () , % machine loads / unloads
  releaseTrack (0) ,
  releaseTrack (1).

loadingMachine () ->
  receive
    {From , permToProcess } ->
      timer : sleep ( rand : uniform (1000)) , % processing
      From !{ doneProcessing },
      loadingMachine ()
  end .

%% activate loading machine and then wait for it to finish
waitForLoadingMachine () ->
  whereis(loading_machine)!{self(), permToProcess},
  receive
    {doneProcessing} ->   done
  end.


releaseTrack ( N ) ->
  whereis ( control_center )!{ self () , release , N}.

acquireTrack ( N ) ->
  whereis(control_center)!{self(), acquire, N},
  receive
    {done, N} -> done
  end.

%% used by acquireTrack and releaseTrack
%% S0 is 0 ( track 0 has been acquired ) or 1 ( track 0 is free )
%% S1 is 0 ( track 1 has been acquired ) or 1 ( track 1 is free )
%% understands two types of messages :
%% {From , acquire ,N} -- acquire track N
%% {From , release ,N} -- release track N
controlCenterLoop ( S0 , S1 ) ->
  receive
    {From, release, 0} ->
      controlCenterLoop(1+S0, S1);
    {From, release, 1} ->
      controlCenterLoop(S0, 1+ S1);
    {From, acquire, 0} when S0 > 0 ->
      From!{done, 0},
      controlCenterLoop(S0-1, S1);
    {From, acquire,1} when S1 > 0 ->
      From!{done, 1},
      controlCenterLoop(S0,S1-1)
  end.