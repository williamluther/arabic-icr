function ProgressiveRecognizerPen (DataFolder, Closest)
% Pen-Like data processing template
% pen.m is a GUI ready to use
%       the GUI calls a function called "process_data"

global in_writing;
global himage;

global folder kNN;
folder = DataFolder;
kNN = Closest;

ClearAll();

in_writing = 0;

% create the new figure
himage = figure;

set(himage,'numbertitle','off');                % treu el numero de figura
set(himage,'name','Progressive Recognizer Pen');% Name
set(himage,'MenuBar','none');                   % remove the menu icon
set(himage,'doublebuffer','on');                % two buffers graphics
set(himage,'tag','PEN');                        % identify the figure
set(himage,'Color',[0.95 0.95 0.95]);
set(himage,'Pointer','crosshair');

% create the axis
h_axes = axes('position', [0 0 1 1]);
set(h_axes,'Tag','AXES');
box(h_axes,'on');
%grid(h_axes,'on');
axis(h_axes,[0 1 0 1]);
%axis(h_axes,'off');
hold(h_axes,'on');

line([0 1],[0.3 0.3],'Color','black','LineWidth',2);
line([0 1],[0.5 0.5],'Color','black','LineWidth',2);
line([0 1],[0.7 0.7],'Color','black','LineWidth',2);

% ######  MENU  ######################################
h_opt = uimenu('Label','&Options');
uimenu(h_opt,'Label','Clear','Callback',@ClearAll);
uimenu(h_opt,'Label','Exit','Callback','closereq;','separator','on');


% create the text
h_text = uicontrol('Style','edit','Units','normalized','Position',[0 0.9 1 0.10],'FontSize',10,'HorizontalAlignment','left','Enable','inactive','Tag','TEXT');

set(himage,'WindowButtonDownFcn',@movement_down);
set(himage,'WindowButtonUpFcn',@movement_up);
set(himage,'WindowButtonMotionFcn',@movement);
uiwait;

% #########################################################################

% #########################################################################
function ClearAll(hco,eventStruct)

global x_pen y_pen RecState;

% erase previous drawing
delete(findobj('Tag','SHAPE'));
delete(findobj('Tag','BOX'));

% delete previous data
x_pen = [];
y_pen = [];

% if necessary
himage = findobj('tag','PEN');

%Initialize parameters for the progressive recognition algorithm
RecState.LCCPI=0; % LastCriticalCheckPointIndex, the corrent root
RecState.CriticalCPs=[]; %Each cell contains the Candidates of the interval from the last CP and the last Point
RecState.CandidateCP=[]; %Holds the first candidate to be a Critical CP after the LCCP

% #########################################################################
% #########################################################################

function movement_down(hco,eventStruct)

global in_writing x_pen y_pen;
%Enter to state 1 as in the first phase we will try to recognize only 1
%stroke word parts.


% toggle
in_writing = 1;

% restore point
h_axes = findobj('Tag','AXES');
p = get(h_axes,'CurrentPoint');
x = p(1,1);
y = p(1,2);

% cumulative data
x_pen = [x_pen x];
y_pen = [y_pen y];

set(findobj('Tag','TEXT'),'String','Current State: 1 ');

% draw
plot(h_axes,x,y,'b.','Tag','SHAPE','LineWidth',3);
% #########################################################################

% #########################################################################
function movement_up(hco,eventStruct)
global in_writing x_pen y_pen;

% toggle
in_writing = 0;

h_axes = findobj('Tag','AXES');

% analysis of what has been pressed
% delete box above
delete(findobj('Tag','BOX'));

% marcar un requadre
x_i = min(x_pen);
x_f = max(x_pen);
x_d = max([1 (x_f - x_i)]);
y_i = min(y_pen);
y_f = max(y_pen);
y_d = max([1 (y_f - y_i)]);
plot(h_axes,[x_i x_f x_f x_i x_i],[y_i y_i y_f y_f y_i],'K:','MarkerSize',22,'Tag','BOX');
process_data(x_pen,y_pen,true);
%close;
% #########################################################################

% #########################################################################
function movement(hco,eventStruct)

global in_writing x_pen y_pen;

if in_writing
    % button pressing
    
    h_axes = findobj('Tag','AXES');
    
    p = get(h_axes,'CurrentPoint');
    x = p(1,1);
    y = p(1,2);
    
    
    if ((y < 0) || (y > 1) || (x < 0) || (x > 1))
        % do nothing
        return;
    end
    
    if ((x ~= x_pen(end)) || (y ~= y_pen(end)))
        % next point
        x_pen = [x_pen x];
        y_pen = [y_pen y];
        
        plot(h_axes,[x_pen(end-1) x],[y_pen(end-1) y],'b.-','Tag','SHAPE','LineWidth',3);
    end
    process_data(x_pen,y_pen,false);
end

% #########################################################################

function simulate(sequence)
len = size(sequence,2);
for k=1:len-1
    process_data(sequence(k,1),sequence(k,2),false);
end
process_data(sequence(len,1),sequence(k,2),true);


% #########################################################################
function process_data(x_pen,y_pen,IsMouseUp)
% x_pen, y_pen are the current point locations
global RecState;

Sequence(:,1) = x_pen;
Sequence(:,2) = y_pen;


Alg = {'EMD' 'MSC' 'kdTree'};

% Algorithm parameters
RecParams.theta=0.144;
RecParams.K = 20;
RecParams.ST = 0.05; %Simplification algorithm tolerance
RecParams.MinLen = 0.4;
RecParams.MaxSlope = 0.3;
RecParams.PointEnvLength=5;

Old_LCCPI = RecState.LCCPI;

RecState = ProcessNewPoint(Alg,RecParams,RecState,Sequence,IsMouseUp);

%Update the heading in the Pen Window
if (Old_LCCPI < RecState.LCCPI || IsMouseUp==true)
     UpdateHeading(RecState);
end

%Output all the candidates.
if (IsMouseUp==true)
    DisplayCandidates(RecState)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%   CORE FUNCTIONS   %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function RecState=ProcessNewPoint(Alg,RecParams,RecState,Sequence,IsMouseUp)
Old_LCCPI = RecState.LCCPI;

CurrPoint = size(Sequence,1);
if(IsMouseUp==true)
    if (RecState.LCCPI == 0)
        if (~isempty(RecState.CandidateCP))
            Merged = TryToMerge(Sequence,RecState.CandidateCP.Point,CurrPoint);
            if (Merged==1)
                %[7] - CP(merged - old CP and the remainder)
                SubSeq = Sequence;
                LetterPos = 'Iso';
                RecognizeAndAddCriticalPoint(SubSeq,Alg,LetterPos,RecState);
            else
                %[5]
                Option1 = CreateOptionDouble(Sequence,0,RecState.CandidateCP.Point,'Ini',RecState.CandidateCP.Point,CurrPoint.Point,'Fin');
                Option2 = CreateOptionSingle(Sequence,0,CurrPoint.Point,'Iso');
                BO = BetterOption(Sequence, Option1, Option2);
                if (BO==1)
                %Add 2 Critical Points 'Ini','Fin'
                else
                %Add 1 Critical Point 'Iso'    
                end
            end
        else
            %[6]
            SubSeq = Sequence;
            LetterPos = 'Iso';
            RecognizeAndAddCriticalPoint(SubSeq,Alg,LetterPos,RecState);
        end
    else
         if (~isempty(RecState.CandidateCP))
             Merged = TryToMerge(Sequence,RecState.CandidateCP.Point,CurrPoint);
              if (Merged==1)
                  %[3]Critical CP -> CP(merged - old CP and the remainder)
              else
                %[1]
                LCCPP = RecState.CriticalCPs(RecState.LCCPI).Point;
                Option1 = CreateOptionDouble(Sequence,LCCPP,RecState.CandidateCP.Point,'Med',RecState.CandidateCP.Point,CurrPoint.Point,'Fin');
                Option2 = CreateOptionSingle(Sequence,LCCPP,CurrPoint.Point,'Fin');
                BO = BetterOption(Sequence, Option1, Option2);
                if (BO==1)
                %Add 2 Critical Points 'Med','Fin'
                else
                %Add 1 Critical Point 'Fin'    
                end
              end
         else
             LCCPP = RecState.CriticalCPs(RecState.LCCPI).Point;
             Merged = TryToMerge(Sequence,LCCPP,CurrPoint);
             if (Merged==1)
                %[4]Critical CP -> New Critical CP(merged with remainder)
                if(RecState.LCCPI>1)
                    BLCCPP = RecState.CriticalCPs(RecState.LCCPI-1).Point;
                else
                    BLCCPP = 0;
                end
                SubSeq = Sequence(BLCCPP:CurrPoint,:);
                LetterPos = 'Fin';
                RecognizeAndAddCriticalPoint(SubSeq,Alg,LetterPos,RecState);
              else
                  %[2]
                  SubSeq = Sequence(LCCPP:CurrPoint,:);
                  LetterPos = 'Fin';
                  RecognizeAndAddCriticalPoint(SubSeq,Alg,LetterPos,RecState);
              end
         end  
    end    
%     %1. It is the first letter (RecState.LCCPI == 0) or not.
%     if (RecState.LCCPI == 0)
%         LCCPP = 0;
%         SubSeq = Sequence;
%         IsIni = true;
%     else
%         %we check whether it better to combine the residual with the
%         %previous Checkpoint 
%         LCCPP = RecState.CriticalCPs(RecState.LCCPI).Point;
%         SubSeq= Sequence(LCCPP:CurrPoint,:);
%         IsIni = false;
%         
%     end
%     RecognitionResults = RecognizeSequence(SubSeq , Alg, IsIni); 
%     %2. There was a Candidate from the last critical point or not.      
%     if (isempty(RecState.CandidateCP))
%         %Try to combine with the previous critical check point or create a
%         %new critical check point.
%         currCP.Candidates=RecognitionResults;
%         currCP.Point = CurrPoint;  
%         RecState.CriticalCPs = [RecState.CriticalCPs;currCP];
%         RecState.LCCPI = RecState.LCCPI + 1; 
%         MarkOnSequence('CriticalCP',Sequence,currCP.Point);
%     else
%         
%         %Try to see if its better to LCCP->C1->end or LCCP->end
%         currCP.Candidates=RecognitionResults;
%         currCP.Point = CurrPoint;
%         SCP = BetterCP (RecState.CandidateCP,currCP);
%         if (SCP.Point==RecState.CandidateCP.Point)
%             RecState.CriticalCPs = [RecState.CriticalCPs;RecState.CandidateCP];
%             MarkOnSequence('CriticalCP',Sequence,RecState.CandidateCP.Point);
%             RecState.LCCPI = RecState.LCCPI+1;
%             %Recognize from CP to Mouse UP
%             SubSeq= Sequence(RecState.CandidateCP.Point:CurrPoint,:);
%             simplified = CalculateSimplifiedSequence (Sequence,CurrPoint,RecState,RecParams.ST);
%             seqLen = CalculateSequenceLength (Sequence,CurrPoint,RecState);
%             slope = CalculateSlope(Sequence,CurrPoint,RecParams.PointEnvLength);
%             if (IsCheckPoint(seqLen,simplified,slope,RecParams))
%                 SCP.Candidates = RecognizeSequence(SubSeq , Alg, false);
%                 SCP.Point = CurrPoint;
%                 RecState.CriticalCPs = [RecState.CriticalCPs;RecState.CandidateCP];
%                 MarkOnSequence('CriticalCP',Sequence,RecState.CandidateCP.Point);
%                 RecState.LCCPI = RecState.LCCPI+1;
%             end
%         else
%         RecState.CriticalCPs = [RecState.CriticalCPs;SCP];
%         RecState.LCCPI = RecState.LCCPI + 1;
%         MarkOnSequence('CriticalCP',Sequence,SCP.Point);
%         end
%     end
else    %Mouse not up  
    if (rem(CurrPoint,RecParams.K)==0) 
        MarkOnSequence('CandidatePoint',Sequence,CurrPoint);
        
        %Calculate Decision Parameters
        simplified = CalculateSimplifiedSequence (Sequence,CurrPoint,RecState,RecParams.ST);
        seqLen = CalculateSequenceLength (Sequence,CurrPoint,RecState);
        slope = CalculateSlope(Sequence,CurrPoint,RecParams.PointEnvLength);
        
        %CheckAlternativeCondition(seqLen,simplified,slope,RecParams.MinLen,RecParams.MaxSlope);
        
        % set LCCPP, IsIni, SubSeq
        if ( RecState.LCCPI == 0)
            LCCPP = 0;
            SubSeq = Sequence;
            IsIni = true;
        else
            LCCP = RecState.CriticalCPs(RecState.LCCPI);
            LCCPP = LCCP.Point;
            SubSeq= Sequence(LCCPP:CurrPoint,:);
            IsIni = false;
        end
        
        if (~isempty(RecState.CandidateCP))
            sub_s= Sequence(RecState.CandidateCP.Point:CurrPoint,:);
            Simplified  = dpsimplify(sub_s,RecParams.ST);
            if (size(Simplified,1)>2)
                MoreInfo = true;
            else
                MoreInfo = false;
            end
        else
            MoreInfo = true;
        end
            
            
        if (IsCheckPoint(seqLen,simplified,slope,RecParams) && Sequence(CurrPoint,1)<Sequence(CurrPoint-1,1) && MoreInfo)
            MarkOnSequence('CheckPoint',Sequence,CurrPoint);
            
            RecognitionResults = RecognizeSequence(SubSeq , Alg, IsIni);
            if (isempty(RecState.CandidateCP))
                RecState.CandidateCP.Candidates = RecognitionResults;
                RecState.CandidateCP.Point = CurrPoint;
            else
                currCP.Candidates=RecognitionResults;
                currCP.Point = CurrPoint;
                SCP = BetterCP (RecState.CandidateCP,currCP);
                RecState.CriticalCPs = [RecState.CriticalCPs;SCP];
                RecState.LCCPI = RecState.LCCPI + 1;
                if (SCP.Point<CurrPoint)
                    RecState.CandidateCP = currCP;
                else
                    RecState.CandidateCP = [];
                end
            end
            
            if (Old_LCCPI < RecState.LCCPI)
                MarkOnSequence('CriticalCP',Sequence,SCP.Point);
            end
        else
            %Notify which condition didn't hold.
            %DisplayUnsutisfiedConditions(seqLen,simplified,slope,RecParams.MinLen,RecParams.MaxSlope);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%    HELPER FUNCTIONS   %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function RecognizeAndAddCriticalPoint(CurrPoint,SubSeq,Alg,LetterPos,RecState)
RecognitionResults = RecognizeSequence(SubSeq , Alg, LetterPos);
currCP.Candidates=RecognitionResults;
currCP.Point = CurrPoint;
RecState.CriticalCPs = [RecState.CriticalCPs;currCP];
RecState.LCCPI = RecState.LCCPI + 1;
MarkOnSequence('CriticalCP',Sequence,currCP.Point);
        

function BCP = BetterCP (CP1,CP2)
sum1=0;
sum2=0;
NumCandidates = size(CP1.Candidates,1);
for k=1:NumCandidates
    sum1 = sum1 + CP1.Candidates{k,2};
    sum2 = sum2 + CP2.Candidates{k,2};
end

if (sum1<sum2)
    BCP = CP1;
else
    BCP = CP2;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Res = IsCheckPoint(SequenceLength,SimplifiedSequence,Slope,RecParams)
%A candidate point is a Checkpoint only if all the below are valid:
%1. The current Sub sequence is longer than MinLen
%2. The current Sub sequence contains enough information
%3. The point environmnt is horizontal
MinLen=RecParams.MinLen;
MaxSlope=RecParams.MaxSlope;
Res = (SequenceLength> MinLen && length(SimplifiedSequence)>3 && Slope<MaxSlope) || (Slope<MaxSlope && length(SimplifiedSequence)*SequenceLength>MinLen);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Slope] = CalculateSlope(Sequence,CurrPoint,PointEnvLength)
start_env= Sequence(CurrPoint-PointEnvLength,:);
end_env= Sequence(CurrPoint,:);
Slope = abs((end_env(2)-start_env(2))/(end_env(1)-start_env(1)));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [SeqLen] = CalculateSequenceLength (Sequence,CurrPoint,RecState)
LCCPI=RecState.LCCPI;
if(LCCPI==0)
    SeqLen = SequenceLength(Sequence);
else
    LastCCP = RecState.CriticalCPs(LCCPI);
    sub_s= Sequence(LastCCP.Point:CurrPoint,:);
    SeqLen = SequenceLength(sub_s);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Simplified] = CalculateSimplifiedSequence (Sequence,CurrPoint,RecState,ST)
LCCPI=RecState.LCCPI;

if(LCCPI==0)
    Simplified  = dpsimplify(Sequence,ST);
else
    LastCCP = RecState.CriticalCPs(LCCPI);
    sub_s= Sequence(LastCCP.Point:CurrPoint,:);
    Simplified  = dpsimplify(sub_s,ST);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%    PRINTING/TEST FUNCTIONS   %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function CheckAlternativeCondition(SequenceLength,SimplifiedSequence,Slope,MinLen,MaxSlope)
%for testing only - check when the second condition holds alone
if ((Slope<MaxSlope && (length(SimplifiedSequence)-1)*SequenceLength>MinLen) && ~(SequenceLength> MinLen && length(SimplifiedSequence)>3 && Slope<MaxSlope))
    len_simp_str=num2str(length(SimplifiedSequence));
    seqLen_str=num2str(SequenceLength);
    MinLen_str = num2str(MinLen);
    disp(['WARNING: length(simplified)= ',len_simp_str,'   seqLen = ',seqLen_str,'  >  ',MinLen_str]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function DisplayUnsutisfiedConditions(seqLen,simplified,slope,MinLen,MaxSlope)
if (seqLen <= MinLen)
    display('Sub-Sequence length too Short')
end
if (length(simplified)<=2)
    display ('Sub-Sequence is too Simple')
end
if (slope>=MaxSlope)
    display ('The point environment is not Horizontal Enough')
end
display(' ')
display(' ')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function MarkOnSequence(Type,Sequence,Point)
switch Type
    case 'CandidatePoint',
        plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'c.-','Tag','SHAPE','LineWidth',7);
        return;
    case 'CheckPoint'
        plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'g.-','Tag','SHAPE','LineWidth',10);
        return;
    case 'CriticalCP'
        plot(findobj('Tag','AXES'),Sequence(Point-1:Point,1),Sequence(Point-1:Point,2),'r.-','Tag','SHAPE','LineWidth',7);
        return;
    otherwise
        return;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function UpdateHeading (RecState)
LCCPI=RecState.LCCPI;
stat_str= num2str(LCCPI);
str = '';

if (LCCPI==1)     
    LCCP = RecState.CriticalCPs(LCCPI);
    CurrCan = LCCP.Candidates;
    for i=1:length(CurrCan)
        str = [str,'  ',CurrCan{i,1}{1}];
    end
    endIndex = num2str(LCCP.Point);
    set(findobj('Tag','TEXT'),'String',['[Current State: ', stat_str,']  ',' Interval: 0 - ',  endIndex, ' Candidates: ' str]);
else 
    LCCP = RecState.CriticalCPs(LCCPI);  
    CurrCan = LCCP.Candidates;
    for i=1:length(CurrCan)
        str = [str,'  ',CurrCan{i,1}{1}];
    end
    BLCCP = RecState.CriticalCPs(LCCPI-1);
    startIndex = num2str(BLCCP.Point);
    endIndex = num2str(LCCP.Point);
    set(findobj('Tag','TEXT'),'String',['[Current State: ' stat_str, ']  ','   Previous State:- ',' Interval: ' , startIndex, ' - ',  endIndex, '   Candidates: ' str]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function DisplayCandidates (RecState)
for i=1:RecState.LCCPI
    if (i==1)
        startIndex = num2str(0);
    else
        BLCCPP = RecState.CriticalCPs(i-1).Point;
        startIndex = num2str(BLCCPP);
    end
    LCCP =  RecState.CriticalCPs(i);
    LCCPP = LCCP.Point;
    endIndex = num2str(LCCPP);
    i_str = num2str(i);
    disp (['State : ',i_str,',  ',startIndex,' - ',endIndex])
    CurrCan = LCCP.Candidates(:,1);
    str = '';
    for j=1:size(CurrCan,1)
        str = [str,' ',CurrCan{j}{1}];
    end
    disp(['Candidates:  ',str])
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%     EOF      %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%