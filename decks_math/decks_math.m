function []=decks_math()
try
%% Preparatory steps
    % basic experiment settings
    randSeed=sum(100*clock);
    rand('twister',randSeed); %reset the random number generator
    mon=0; %which monitor to use?  1 for secondary, 0 for primary
    nRuns=8; %normally 8
    secsPerRun=.5*60; %runs are timed. normally 5mins (5*60)
    leftResp=',4z1';
    rightResp='.3x2';
    bothResps={leftResp,rightResp};
    
    % color parameters
    bkgd=47; %intensity level of background gray
    texBkgd=[bkgd,bkgd,bkgd,0]; %transparent background(?)
    white=255;
    black=0;
    Screen('Preference','TextAlphaBlending',1);
    
    %prepare data array
    datarow=0;
    data.randSeed=randSeed;
    data.runNum=[];
    data.trialNum=[];
    data.choice=[];
    data.optOnsetTime=[];
    data.choiceRT=[];
    data.terms={};
    data.targResp={};
    data.targAcc=[];
    data.targOnsetTime=[];
    data.targRT=[];
    data.easyRect={};
    data.hardRect={};
    data.chosenRect={};

    %%%%%% Prepare stimuli %%%%%%
    %load fractal images, which are 128 pixel squares; put them on 300
    %pixel fields
    field=128;
    ground=150;
    buffer=30; %edge area of rectangle that won't trigger a selection
    bufferRim=[buffer,buffer,-buffer,-buffer]; %add this to shrink a rect
    margin=(ground-field)/2; %equals 86
    fieldB=margin+1; fieldE=ground-margin;
    stim_names={'abst01a' 'abst01b'
                'abst02a' 'abst02b'
                'abst03a' 'abst03b'
                'abst04a' 'abst04b'
                'abst05a' 'abst05b'
                'abst06a' 'abst06b'
                'abst07a' 'abst07b'   
                'abst08a' 'abst08b'};
    stims={{} {};
           {} {};
           {} {};
           {} {};
           {} {};
           {} {};
           {} {};
           {} {}};
    W=zeros(ground); %how strongly each pixel is dominated by the background color in the 'used' version
    R_in=ceil(field*5/16); %radius of inner field where number is shown
    R_out=ceil(field*7/16); %outer radius of faded ring around the field
    for x=1:ground
        for y=1:ground
            r=sqrt(abs(x-ground/2)^2+abs(y-ground/2)^2);
            if r<R_in %if in the inner field
                W(x,y)=1;
            elseif r<R_out %if in the faded ring around the field
                W(x,y)=(R_out-r)/(R_out-R_in);
            end %portions outside the ring will remain at zero
        end
    end
    W(:,:,2)=W(:,:,1);
    W(:,:,3)=W(:,:,1); %give W three pages
    for row=1:size(stim_names,1);
        for diff=1:2
            stims{row,diff}{1}=bkgd*ones(ground,ground,3);
            stims{row,diff}{1}(fieldB:fieldE,fieldB:fieldE,:)=imread(['colorStims/',stim_names{row,diff},'.bmp']);
            stims{row,diff}{2}=W*bkgd+(1-W).*stims{row,diff}{1};
            stims{row,diff}{3}(:,:,1:3)=stims{row,diff}{1};
            stims{row,diff}{3}(:,:,4)=125; %put in an alpha layer
            %alpha note:  0=transparent, 255=opaque
        end
    end
    %2 items in the same row of stims are contrasting stimuli,
    %for use together in a condition.  The assignment of 
    %pair-members to hard/easy is counterbalanced once a
    %subject is started.  
    %Each cell of stims holds an array of two cells.  The first is the
    %whole pattern patch; the second is the 'used' version with a blank
    %field for showing the number.  
    
    %create home cue
    homeSz=17;
    homeX=ones(homeSz,homeSz,3)*bkgd;
    for x=1:homeSz
        for y=1:homeSz
            %to make an X
            %if ismember(x,[y-1:y+1]) || ismember(10-x,[y-1:y+1]) %an X
            %    homeX(x,y,:)=[255,255,255];
            %end
            %to make a bullseye
            if sqrt(power(abs(x-homeSz/2),2)+power(abs(y-homeSz/2),2))<8 %white circle
                homeX(x,y,:)=white;
            end
            if sqrt(power(abs(x-homeSz/2),2)+power(abs(y-homeSz/2),2))<5.5 %black circle
                homeX(x,y,:)=black;
            end
            if sqrt(power(abs(x-homeSz/2),2)+power(abs(y-homeSz/2),2))<2 %white center
                homeX(x,y,:)=white;
            end
        end
    end
    %%%%%% Done preparing stimuli %%%%%%
    
%% Experiment starts
    id=[];
    while isempty(id)
        id=input('Subject ID:  ','s');
    end
    subNum=[];
    while isempty(subNum)
        subNum=input('Subject number:  ');
    end
    if subNum<10, subStr=['s0',num2str(subNum)]; else subStr=['s',num2str(subNum)]; end
    data.subjectID=id;
    data.subjectNumber=subNum;
    session=0;
    uniqueSession=0;
    while ~uniqueSession %increase session number till filename is unique
        session=1+session;
        sessionStr=num2str(session);
        dataFileName=['decksMath_data_',subStr,'_',id,'_',sessionStr,'.mat'];
    	if exist(dataFileName,'file')~=2, uniqueSession=1; end
    end 
    input(['Data will be saved in ',dataFileName,' (ENTER to continue)  ']);
    
    %EH MAPPING
    %Assign columns 1 and 2 of stims to be easy or hard
    if mod(subNum,2)==1 %for odd numbered subjects
        easyStim=1;
        hardStim=2;
    else
        easyStim=2;
        hardStim=1;
    end
    
    HideCursor;
    ListenChar(2);
    Priority(7);
       
    % open main screen
    [wid,wRect] = Screen('OpenWindow',mon,bkgd);
    xcen = floor(wRect(3)/2);
    ycen = floor(wRect(4)/2);
    
    % open offscreen windows
    [widMessage] = Screen('OpenOffscreenWindow',mon,bkgd);
    [widOptions] = Screen('OpenOffscreenWindow',mon,bkgd);
    [widOptionsDim] = Screen('OpenOffscreenWindow',mon,bkgd);
    [widOptionsE] = Screen('OpenOffscreenWindow',mon,bkgd);
    [widOptionsH] = Screen('OpenOffscreenWindow',mon,bkgd);
    [widTargetE] = Screen('OpenOffscreenWindow',mon,bkgd);
    [widTargetH] = Screen('OpenOffscreenWindow',mon,bkgd);

    %explicitly set alpha blending for certain screens
    Screen('BlendFunction',widOptionsDim,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    Screen('BlendFunction',wid,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    Screen('BlendFunction',widMessage,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    Screen('BlendFunction',widTargetE,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    Screen('BlendFunction',widTargetH,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    
    % define the circle on which stimuli will appear
    diameter=min([RectWidth(wRect),RectHeight(wRect)])-ground-100;
    radius=diameter/2;
    %the circle of potential stim positions has a diameter equal to the
    %smaller screen dimension, minus the width==height of the stimuli
    %(150), minus some additional padding factor.
    
    %set up text formatting parameters
    texSiz=40;
    Screen(widMessage,'TextColor',255);
    Screen(widMessage,'TextSize',texSiz);
    
%% Stimulus sequence begins
    %randomize the first set of option positions
    theta=ceil(8*rand)*pi/4;
    for runNum=1:nRuns
        
        % create rectangles for stimuli in this run
        vec1=theta-pi/7;
        vec2=theta+pi/7;
        point1=radius*[cos(vec1),sin(vec1)]+[xcen,ycen];
        point2=radius*[cos(vec2),sin(vec2)]+[xcen,ycen];
        pointM=round((point1+point2)/2);
        
        %randomly assign positions to hard and easy
        if rand<.5
            easyPoint=point1; hardPoint=point2;
        else
            easyPoint=point2; hardPoint=point1;
        end
        homeRect=[pointM-(homeSz-1)/2,pointM+(homeSz-1)/2];
        easyRect=[easyPoint-ground/2,easyPoint+ground/2]; %stimulus rectangle
        hardRect=[hardPoint-ground/2,hardPoint+ground/2];
        easyRectTarg=easyRect+bufferRim; %response collection rectangle
        hardRectTarg=hardRect+bufferRim;
        
        % create screens
        % a screen with both options
        Screen('FillRect',widOptions,bkgd);
        Screen('PutImage',widOptions,stims{runNum,easyStim}{1},easyRect);
        Screen('PutImage',widOptions,stims{runNum,hardStim}{1},hardRect);
        % a screen w/ home pos visible and options dimmed
        Screen('CopyWindow',widOptions,widOptionsDim);
        Screen('FillRect',widOptionsDim,[bkgd,bkgd,bkgd,125]);
        Screen('PutImage',widOptionsDim,homeX,homeRect);
        % a screen in case the hard one is chosen
        Screen('CopyWindow',widOptions,widOptionsH);
        Screen('PutImage',widOptionsH,stims{runNum,hardStim}{2},hardRect);
        % a screen in case the easy one is chosen
        Screen('CopyWindow',widOptions,widOptionsE);
        Screen('PutImage',widOptionsE,stims{runNum,easyStim}{2},easyRect);
        
        %show the run-start message
        message=['Part ',num2str(runNum),' of ',num2str(nRuns)];
        submessage='Press a key to start.';
        nested_message(message,submessage,'','12');
        Screen('FillRect',wid,bkgd);
        runOnset=Screen('Flip',wid');
        SetMouse(xcen,ycen,wid);
        trialNum=0;
        WaitSecs(1); %the start-of-run interval (blank screen)
        
        % present trials until the allotted time is up
        while GetSecs<(runOnset+secsPerRun)
            datarow=datarow+1; %line of the data file to write on
            trialNum=trialNum+1; % trialNum restarts each run
            
            % display the home position
            ShowCursor(0);
            Screen('CopyWindow',widOptionsDim,wid);
            Screen('Flip',wid);
            
            % create a subtraction problem to show for easy and for hard.
            [textureE,correctE,dimsE,termsE]=genTarg(1); %generate an easy target
            [textureH,correctH,dimsH,termsH]=genTarg(2); %generate a hard target
            
            % prepare the two possible subtraction problems for display
            Screen('CopyWindow',widOptionsE,widTargetE);
            Screen('CopyWindow',widOptionsH,widTargetH);
            easyRect=[easyPoint-ceil(dimsE/2),easyPoint+floor(dimsE/2)];
            hardRect=[hardPoint-ceil(dimsH/2),hardPoint+floor(dimsH/2)];
            Screen('DrawTexture',widTargetE,textureE,[],easyRect);
            Screen('DrawTexture',widTargetH,textureH,[],hardRect);
            
            % wait for a homing response and then brighten the choice cues
            Screen('CopyWindow',widOptions,wid);
            homed=0;
            while homed==0
                [x,y,buttons]=GetMouse(wid);
                if IsInRect(x,y,homeRect)
                    homed=1;
                    optOnset=Screen('Flip',wid);
                end
                WaitSecs(.001);
            end
            
            % now allow the subject to select one of the options.
            ShowCursor(0);
            trialtype=0; %(will be 1 for easy, 2 for hard)
            while trialtype==0
                [x,y,buttons]=GetMouse(wid);
                secs=GetSecs;
                if IsInRect(x,y,hardRectTarg)
                    trialtype=2;
                    cor_resp=bothResps{correctH};
                    textureActual=textureH;
                    rectActual=hardRect;
                    optionsActual=widOptionsH;
                    termsActual=termsH;
                    Screen('CopyWindow',widTargetH,wid);
                elseif IsInRect(x,y,easyRectTarg)
                    trialtype=1;
                    cor_resp=bothResps{correctE};
                    textureActual=textureE;
                    rectActual=easyRect;
                    optionsActual=widOptionsE;
                    termsActual=termsE;
                    Screen('CopyWindow',widTargetE,wid);
                end
                WaitSecs(.001);
            end
            choiceTimestamp=secs;
            targOnset=Screen('Flip',wid);
            
            % collect a response to the target
            HideCursor;
            responded=0;
            while responded==0
                [keyIsDown,secs,keyCode]=KbCheck;
                [x,y,buttons]=GetMouse(wid);
                if keyIsDown==1 || any(buttons>0) %if the first response has just occurred
                    resp=[KbName(keyCode),num2str(find(buttons))];
                    if any(ismember(resp,cor_resp)) %if correct
                        accuracy=1;
                        feedbackColor=[50 150 50];
                        responded=1;
                    elseif any(ismember(resp,[leftResp rightResp])) %if allowable
                        accuracy=0;
                        feedbackColor=[200 50 50];
                        responded=1;
                    end
                end
                WaitSecs(.001);
            end
            responseTimestamp=secs;
            targetResponse=resp;
            
            % show feedback
            Screen('CopyWindow',optionsActual,wid);
            Screen('DrawTexture',wid,textureActual,[],rectActual,[],[],[],feedbackColor);
            Screen('Flip',wid);
            Screen('CopyWindow',optionsActual,wid);
            WaitSecs(.25);
            Screen('Flip',wid); %show the blank field for the ITI

            % close unneeded textures
            Screen('Close',[textureE textureH]);
            
            %log data
            data.runNum(datarow,1)=runNum;
            data.trialNum(datarow,1)=trialNum;
            data.choice(datarow,1)=trialtype; %1=easy, 2=hard
            data.optOnsetTime(datarow,1)=optOnset;
            data.choiceRT(datarow,1)=choiceTimestamp-optOnset;
            data.terms{datarow,1}=termsActual;
            data.targResp{datarow,1}=targetResponse;
            data.targAcc(datarow,1)=accuracy;
            data.targOnsetTime(datarow,1)=targOnset;
            data.targRT(datarow,1)=responseTimestamp-targOnset;
            data.easyRect{datarow,1}=easyRect;
            data.hardRect{datarow,1}=hardRect;
            data.chosenRect{datarow,1}=rectActual;
            
            % wait through the iti
            WaitSecs(.25); 
            buttons=[1 1 1];
            while any(buttons);
                [x,y,buttons]=GetMouse(wid);
                WaitSecs(.001); % wait till mouse buttons are released
            end
            
        end %trials in a run
        
        % tasks at the end of every run
        theta=theta+3*pi/4; % reset choice cue positions for next run
        save(dataFileName,'data'); % save datafile
        Screen('FillRect',wid,bkgd);
        Screen(wid,'Flip');
        WaitSecs(1); % end-of-run interval (blank screen)
        
    end %runs
    nested_message('Task complete.',' ','s','');
    
    % close out sequence
    % flip colors to signal safe exit
    Screen('FillRect',wid,[200,100,20]);
    Screen(wid,'Flip');
    WaitSecs(.5);
    Screen('FillRect',wid,[20,100,200]);
    Screen(wid,'Flip');
    WaitSecs(.5);
    
    % close screen and return system to normal
    Screen('CloseAll');
    ShowCursor; %display mouse cursor again
    ListenChar(0); %allow keystrokes to Matlab
    Priority(0); % return Matlab's priority level to normal
    Screen('Preference','TextAlphaBlending',0);
catch
    save(dataFileName,'data'); %save data if crashing
    Screen('CloseAll'); %close screen
    ShowCursor; %display mouse cursor again
    ListenChar(0); %allow keystrokes to Matlab
    Priority(0); % return Matlab's priority level to normal
    Screen('Preference','TextAlphaBlending',0);
    disp(lasterror);
end %try-catch loop

quickAnalysis(dataFileName); % plot some basic statistics

%% Nested function to show a message screen
function [resp]=nested_message(message,submessage,resp_set,resp_setM)
    %displays a message in white in the center of the screen
    %displays a submessage in small text below it
    %blanks and returns upon receiving a response in resp_set
    %No data logging.
    %Set submessage to ' ' (space) for no submessage
    %If resp_set is '', any keyboard response is ok
    Screen(widMessage,'FillRect',bkgd); %clear it
    width=RectWidth(Screen('TextBounds',widMessage,message));
    Screen(widMessage,'DrawText',message,xcen-width/2,ycen-30,white,texBkgd);
    Screen(widMessage,'TextSize',36);
    width=RectWidth(Screen('TextBounds',widMessage,submessage));
    Screen(widMessage,'DrawText',submessage,xcen-width/2,ycen+52,white,texBkgd);
    Screen(widMessage,'TextSize',40);
    Screen('CopyWindow',widMessage,wid);
    onset_stamp = Screen(wid,'Flip');
    secs=onset_stamp;
    responded=0;
    while responded==0
        [keyIsDown,secs,keyCode]=KbCheck;
        [x,y,buttons]=GetMouse(wid);
        if keyIsDown==1 && responded==0 %if the first resp has just occurred
            if isempty(resp_set) || any(ismember(KbName(keyCode),resp_set))
             %if the keyboard response is allowable
                responded=1;
                resp=KbName(keyCode);
            end
        elseif any(ismember(num2str(find(buttons)),resp_setM))
         %if the mouse response is allowable
            responded=1;
            resp=num2str(find(buttons));

        else
            WaitSecs(.001);
        end
    end
    %Screen('FillRect',wid,255);
    %Screen(wid,'Flip');
    %set up a blank screen
end %of function nested_message
    
% function to generate target stimuli
function [texture,correct,rectDims,terms]=genTarg(targType)
    % produces either a correct or incorrect subtraction problem on a
    % texture.
    % targType:  2=hard (requires a carry), 1=easy
    % correct:  1=target, 2=lure
    % constraints:  minuend is at least 30; subtrahend is at least 10,
    % and they differ by more than 10.  Ones digit of the minuend is
    % greater (than ones digit of subtrahend) for easy, less for hard.
    % If incorrect: given answer off by -2, -1, +1, or +2. 

    correct=2-round(rand);
    % select numbers for the subtraction problem
    minuend_tens=ceil(3+6*rand);
    subtrahend_tens=ceil((minuend_tens-2)*rand);
    onesDig=[0 0];
    while onesDig(1)==onesDig(2)
        onesDig=ceil(9*rand(1,2));
    end
    if targType==1
        minuend_ones=max(onesDig);
        subtrahend_ones=min(onesDig);
    elseif targType==2
        minuend_ones=min(onesDig);
        subtrahend_ones=max(onesDig);
    end
    minuend=str2double([num2str(minuend_tens),num2str(minuend_ones)]);
    subtrahend=str2double([num2str(subtrahend_tens),num2str(subtrahend_ones)]);
    difference=minuend-subtrahend;
    possibleIncrements=[-2 -1 1 2];
    if correct==2
        increment=possibleIncrements(ceil(4*rand));
        difference=difference+increment;
    end
    terms=[minuend,subtrahend,difference];
    minuend=num2str(minuend);
    subtrahend=num2str(subtrahend);
    difference=num2str(difference);
    % set parameters of the texture
    mathTextSize=20;
    tMargin=round(mathTextSize/8);
    textureHeight=mathTextSize*3+tMargin*5;
    textureWidth=mathTextSize*2;
    rectDims=[textureWidth,textureHeight];
    texture=Screen('MakeTexture',wid,cat(3,bkgd*ones(textureHeight,textureWidth,3),ones(textureHeight,textureWidth)));
    Screen('TextSize',texture,mathTextSize);
    Screen('TextColor',texture,white);
    % draw numbers onto the texture
    widthMinu=RectWidth(Screen('TextBounds',texture,minuend));
    Screen('DrawText',texture,minuend,textureWidth-widthMinu-tMargin,tMargin,white,texBkgd);
    widthSubt=RectWidth(Screen('TextBounds',texture,subtrahend));
    Screen('DrawText',texture,subtrahend,textureWidth-widthSubt-tMargin,2*tMargin+mathTextSize,white,texBkgd);
    widthDiff=RectWidth(Screen('TextBounds',texture,difference));
    Screen('DrawText',texture,difference,textureWidth-widthDiff-tMargin,3*tMargin+2*mathTextSize,white,texBkgd);
    dashRect=[0,0,mathTextSize/2,2]; % size of minus sign
    dashRect=dashRect+repmat([textureWidth-widthSubt-tMargin-mathTextSize/2,1.5*mathTextSize+3*tMargin],1,2);
    lineRect=[0,0,mathTextSize*1.5,2]; % size of the line
    lineRect=lineRect+repmat([textureWidth-mathTextSize*1.5,3*tMargin+2*mathTextSize],1,2);
    Screen('FillRect',texture,white,dashRect);
    Screen('FillRect',texture,white,lineRect);
end % of function genTarg
       
end %outermost function



                
                
                
                
                
                
            
        
    