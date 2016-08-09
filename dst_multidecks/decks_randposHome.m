function [] = decks_randposHome(prac)
% decks_randposHome
%
% This function presents the demand selection task.
% Cognitive demand is manipulated using magnitude/parity task switching.
% Input:
%   prac (optional) - if set to 'p', runs in practice mode
%       -begins with several blocks of isolated numbers
%       -then shows a short demo of the demand selection task
%       -no data logging
%
% Participants enter responses with a two-button mouse.
% Task switching response rules:
%   yellow digits: left if odd, right if even
%   blue digits: left if lower than 5, right if higher than 5
% 
% DST goes as follows:
%   Both stimulus locations are dimmed and unavailable initially until the 
%   mouse cursor moves to the central "home" location. Then participants 
%   may role the cursor over their chosen location to reveal a stimulus 
%   digit, then respond by clicking based on the mapping above.
% 
% Practice session in more detail:
%   The practice session is under the experimenter's close control; the 
% code is meant to be run in tandem with verbal instructions. It runs as 
% follows:
%   1. Initial screen. Experimenter presses "0" to proceed.
%   2. Block of 20 digits with immediate accuracy feedback.
%   3. Results summary. Experimenter may press "0" to proceed, or "1" to
%   repeat the practice block. Typically it would be repeated if the
%   participant got less than 90% correct. 
%   4. No-feedback blocks. Here the participant gets used to doing the task
%   without immediate feedback. Summary feedback is shown at the end of
%   each block.
%   5. Results summary. Experimenter may press "0" to proceed, or a number
%   from 1 through 9 to present that number of additional practice blocks.
%   6. DST: there is a demonstration of just a few trials of the full
%   selection task so participants can become familiar with it.
%
% At the "Task complete" screen at the end of the full experiment:
%   Experimenter presses "s" to exit.
%
% This file includes the following subfunctions:
%   displayMessage
%   getSubjectInfo
%   genTarg
%   loadStims
%   ts_prac
%   showTsTrial
%   showITI
%
% Last updated by JTM on 11/4/2010

try
    Screen('Preference', 'SkipSyncTests', 1)
    
    % initialize the random number generator
    randSeed = sum(100*clock);
    RandStream.setGlobalStream(RandStream('mt19937ar','seed',randSeed));
    
    % set the task duration
    nRuns = 8; % normally 8
    nTrialsPerRun = 75; % normally 75
    if nargin>0 && strcmp(prac,'p') % different values for practice runs
        nRuns = 1;
        nTrialsPerRun = 4;
    else
        prac = '';
    end
    
    % display parameters
    mon = 0; % 0 for primary monitor
    bkgd = 47; % intensity level of background gray
    Screen('Preference','TextAlphaBlending',0);
    
    % allowable response characters
    allowedResps.left = ',4z1';
    allowedResps.right = '.3x2';
    
    % initialize
    digit = 0;
    color = 1;
    
    % prepare data structure
    nRows = nRuns*nTrialsPerRun;
    data.runNumber = nan(nRows,1);
    data.trialNumber = nan(nRows,1);
    data.easyRect = cell(nRows,1); % rectangle for position of the easy option
    data.hardRect = cell(nRows,1); % rectangle for position of the hard option
    data.choiceOnset = nan(nRows,1); % onset timestamp
    data.choiceRT = nan(nRows,1); % choice response latency
    data.choice = nan(nRows,1); % participant's selection: 1 = easy, 2 = hard
    data.targetColor = nan(nRows,1); % color of the number: 1 = blue, 2 = yellow
    data.targetDigit = nan(nRows,1);
    data.targetOnset = nan(nRows,1); % onset timestamp
    data.targetRT = nan(nRows,1); % response latency to the number
    data.targetResponse = cell(nRows,1); % which key was pressed
    data.targetAccuracy = nan(nRows,1); % response accuracy
    
    % experiment starts
    [id, subNum, dataFileName] = getSubjectInfo(prac);
    HideCursor;
    ListenChar(2);
    Priority(7);
    
    % log general subject and session info
    dataHeader.randSeed = randSeed;
    dataHeader.sessionTime = fix(clock);
    dataHeader.subjectID = id;
    dataHeader.subjectNumber = subNum;
    dataHeader.dataName = dataFileName;
    
    % open an onscreen window
    [wid, wRect] = Screen('OpenWindow',mon,[bkgd*ones(1,3), 255],[],[],[],[],[],kPsychNeedFastBackingStore);
    xcen = floor(wRect(3)/2);
    ycen = floor(wRect(4)/2);
    Screen('BlendFunction',wid,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    
    % the circle of potential stim positions has a diameter set relative to
    % the smaller screen dimension.
    diameter = min([RectWidth(wRect), RectHeight(wRect)])-250;
    radius = diameter/2;
    
    % parameters for the sizes of stimuli
    homeSz = 17; % size of the home position marker
    fbackSz = 50; % size of accuracy feedback signals (in practice session)
    ground = 150; % size of squares with stimulus locations
    buffer = 30; % edge area of rectangle that won't trigger a selection
    bufferRim = buffer*[1, 1, -1, -1]; %add this to shrink a rect
    
    % load stimuli and create textures
    [stimTex, homeTex, fieldTex, digitTex, fbackTex] = loadStims(wid,bkgd,prac,ground,homeSz,fbackSz);
    
    % stimTex holds handles of unique designs marking stimulus locations.
    % Each row (with 2 items) is 1 run.
    % Assignment of the 2 columns to conditions (hard vs easy) is
    % balanced based on odd/even subject number.
    % This applies to the visual stimuli: their locations are randomized
    % later.
    if mod(subNum,2)==1 %for odd numbered subjects
        easyStimTex = stimTex(:,1);
        hardStimTex = stimTex(:,2);
    else % even numbered subjects
        easyStimTex = stimTex(:,2);
        hardStimTex = stimTex(:,1);
    end
    
    % randomly initialize the angle that defines stimulus locations
    % (this will be updated after each run)
    theta = randi(8)*pi/4;
    
    % baseline for event onset timestamps
    exptOnset = GetSecs;
    
    % for practice mode
    % run the initial block: task switching with isolated numbers
    if strcmp(prac,'p')
        center = [xcen, ycen];
        centerRect = [center-ground/2, center+ground/2]; % location of practice stimuli
        fbackCen = [xcen, ycen*4/3];
        fbackRect = [fbackCen-fbackSz/2, fbackCen+fbackSz/2]; % location of practice feedback
        ts_prac(wid,bkgd,centerRect,fbackRect,digitTex,fbackTex,allowedResps); % practice block
    end
    
    %%%% experimental runs
    for runNum = 2:nRuns
        
        %%%% setup at the beginning of a run
        % create rectangles for the hard and easy options
        % each location's angle from the center
        vec1 = theta-pi/7;
        vec2 = theta+pi/7;
        % location centers in x/y coordinates
        point1 = radius*[cos(vec1), sin(vec1)] + [xcen, ycen];
        point2 = radius*[cos(vec2), sin(vec2)] + [xcen, ycen];
        pointM = round((point1+point2)/2); % midpoint
        % rectangle for each stimulus
        rect1 = [point1, point1]+[-1, -1, 1, 1]*ground/2;
        rect2 = [point2, point2]+[-1, -1, 1, 1]*ground/2;
        homeRect = [pointM, pointM]+[-1, -1, 1, 1]*(homeSz-1)/2;
        
        % randomly assign one location to hard and one to easy
        if rand<0.5
            easyRect = rect1;
            hardRect = rect2;
        else
            easyRect = rect2;
            hardRect = rect1;
        end
        
        % define a smaller region for mouse cursor responses
        hardRectTarg = hardRect+bufferRim; 
        easyRectTarg = easyRect+bufferRim;
        
        % pre-run message (accepts any mouse response)
        msg = sprintf('Part %d of %d',runNum,nRuns);
        submsg = 'Click the mouse to start.';
        displayMessage(wid,bkgd,msg,submsg,'','any');
        
        % run begins
        SetMouse(xcen,ycen,wid);
        WaitSecs(1); % initial interval (blank screen)
        
        for trial = 1:nTrialsPerRun
            
            % log preliminary data
            datarow = (runNum-1)*nTrialsPerRun+trial; % current line of the data record
            data.runNumber(datarow,1) = runNum;
            data.trialNumber(datarow,1) = trial;
            data.easyRect{datarow,1} = easyRect;
            data.hardRect{datarow,1} = hardRect;
            
            % generate random digits and colors
            [digitE, colorE, colorRGB_E, corRespE] = genTarg(0.1,digit,color,allowedResps); % low prob of a task switch
            [digitH, colorH, colorRGB_H, corRespH] = genTarg(0.9,digit,color,allowedResps); % high prob of a task switch
            
            % clear the two digit textures
            Screen('FillRect',digitTex.easy,[0, 0, 0, 0]);
            Screen('FillRect',digitTex.hard,[0, 0, 0, 0]);
            
            % draw each digit onto its texture
            DrawFormattedText(digitTex.easy,digitE,'center',ground/2-30,[colorRGB_E, 255]);
            DrawFormattedText(digitTex.hard,digitH,'center',ground/2-30,[colorRGB_H, 255]);
            
            % show cursor and display the home position
            ShowCursor(0);
            Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
            Screen('DrawTexture',wid,homeTex,[],homeRect);
            
            % draw stimulus locations with partial transparency (alpha=0.5)
            Screen('DrawTexture',wid,easyStimTex(runNum,1),[],easyRect,[],[],0.5);
            Screen('DrawTexture',wid,hardStimTex(runNum,1),[],hardRect,[],[],0.5);
            Screen('Flip',wid,[],1);
            
            % wait for a response, then brighten the two locations
            homed = 0;
            while homed==0
                [x, y] = GetMouse(wid);
                if IsInRect(x,y,homeRect)
                    homed = 1;
                else
                    WaitSecs(.001);
                end
            end
            Screen('DrawTexture',wid,easyStimTex(runNum,1),[],easyRect);
            Screen('DrawTexture',wid,hardStimTex(runNum,1),[],hardRect);
            optionsOnset = Screen('Flip',wid,[],1);
            data.choiceOnset(datarow,1) = optionsOnset-exptOnset;
            
            % let the subject select a location with a mouseover response
            trialtype = 0; % (will be set to 1 for easy, 2 for hard)
            while trialtype==0
                [x, y] = GetMouse(wid);
                if IsInRect(x,y,easyRectTarg)
                    data.choiceRT(datarow,1) = GetSecs-optionsOnset;
                    trialtype = 1;
                    stimRect = easyRect;
                    targetTex = digitTex.easy;
                    color = colorE;
                    digit = digitE;
                    corResp = corRespE;
                elseif IsInRect(x,y,hardRectTarg)
                    data.choiceRT(datarow,1) = GetSecs-optionsOnset;
                    trialtype = 2;
                    stimRect = hardRect;
                    targetTex = digitTex.hard;
                    color = colorH;
                    digit = digitH;
                    corResp = corRespH;
                end
                WaitSecs(.001);
            end
            
            % hide cursor and add a gray field over the chosen location
            HideCursor;
            Screen('DrawTexture',wid,fieldTex,[],stimRect);
            
            % show the digit and collect a response
            [resp, rt, accurate, targOnset] = showTsTrial(wid,targetTex,stimRect,corResp,allowedResps);
            
            % record data
            data.choice(datarow,1) = trialtype; % 1 means easy, 2 means hard
            data.targetColor(datarow,1) = color; % index: 1 = blue, 2 = yellow
            data.targetDigit(datarow,1) = str2double(digit);
            data.targetOnset(datarow,1) = targOnset-exptOnset;
            data.targetRT(datarow,1) = rt;
            data.targetResponse{datarow,1} = resp;
            data.targetAccuracy(datarow,1) = accurate;
            
            % remove the number for the ITI (show just the blank field)
            Screen('DrawTexture',wid,easyStimTex(runNum,1),[],easyRect);
            Screen('DrawTexture',wid,hardStimTex(runNum,1),[],hardRect);
            Screen('DrawTexture',wid,fieldTex,[],stimRect);
            Screen('Flip',wid,[],1);
            showITI(wid);
            
        end %trials in a run
        
        % advance to a new stimulus locations for the next run
        % this uses all 8 possible angles across the 8 runs, not in
        % sequential order
        theta = theta+3*pi/4;
        
        %save the data so far
        save(dataFileName,'data','dataHeader');
        
        % show a blank screen briefly at the end of the run
        Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
        Screen(wid,'Flip');
        WaitSecs(1);
        
    end %runs
    
    % experimenter can press 's' to exit the final screen
    if isempty(prac)
        displayMessage(wid,bkgd,'Task complete.','','s','')
    end
    
    % close-out tasks
    Screen('CloseAll');
    ShowCursor; % display mouse cursor again
    ListenChar(0); % allow keystrokes to Matlab
    Priority(0); % return Matlab's priority level to normal
    Screen('Preference','TextAlphaBlending',0);
    
catch ME
    
    % save data
%     save(dataFileName,'data','dataHeader');
    
    % close-out tasks
    Screen('CloseAll'); % close screen
    ShowCursor; % display mouse cursor again
    ListenChar(0); % allow keystrokes to Matlab
    Priority(0); % return Matlab's priority level to normal
    Screen('Preference','TextAlphaBlending',0);
    
    % error information
    disp(getReport(ME));
    keyboard
    
end %try-catch loop

if isempty(prac)
    quickAnalysis(dataFileName);
end

end % main function



%%%%
% function to place a prompt or other message on the screen and wait until
% a response is made
function [resp, rt] = displayMessage(wid,bkgd,msg,submsg,keyresp,mouseresp)
% wid is the onscreen window
% msg is displayed in white at the center of the screen
% submsg is shown in smaller text below it (unless empty)
% clears and returns upon receiving an acceptable response
%   keyresp is a string with acceptable keyboard responses
%   mouseresp is a string with acceptable mouse responses
%   either may be set to 'any' if any response is acceptable
%
% this function does not write anything directly to the data record,
% but it returns the response given and the RT.

white = [255*ones(1,3), 255]; % text color
Screen('FillRect',wid,[bkgd*ones(1,3), 255]); %clear window

% main message
Screen('TextSize',wid,36);
[nx, ny] = DrawFormattedText(wid,msg,'center','center',white);

% sub message
if ~isempty(submsg)
    Screen('TextSize',wid,24);
    DrawFormattedText(wid,submsg,'center',ny+80,white);
end

% display
onset_stamp = Screen(wid,'Flip');

% mandatory delay
WaitSecs(1);

% collect response, checking both mouse and keyboard
responded = 0;
while responded==0
    if ~isempty(keyresp) % check keyboard
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown==1
            responseMatches = any(ismember(KbName(keyCode),keyresp));
            if strcmp(keyresp,'any') || responseMatches % if the response is allowable
                responded = 1;
                resp = KbName(keyCode);
                rt = secs - onset_stamp;
            end
        end
    end
    if ~isempty(mouseresp) % check mouse
        [x, y, buttons] = GetMouse(wid);
        secs = GetSecs;
        if (any(buttons))
            responseMatches = any(ismember(num2str(find(buttons)),mouseresp));
            if strcmp(mouseresp,'any') || responseMatches
                responded = 1;
                resp = num2str(find(buttons));
                rt = secs - onset_stamp;
            end
        end
    end
    WaitSecs(.001);
end

% clear the screen
Screen('FillRect',wid,[bkgd*ones(1,3), 255]);
Screen('Flip',wid);

end



%%%%
% function to obtain subject identifying info
function [id, subNum, dataFileName] = getSubjectInfo(prac)
id = [];
if isempty(prac)
    while isempty(id)
        id = input('Subject ID:  ','s');
    end
    subNum = [];
    while isempty(subNum)
        subNum = input('Subject number:  ');
    end
    session = 1;
    dataFileName = sprintf('decksHome_data_s%02d_%s_%d.mat',subNum,id,session);
    % increase the session number if finding previous data for the same subject
    while exist(dataFileName,'file')==2
        session = 1+session;
        dataFileName = sprintf('decksHome_data_s%02d_%s_%d.mat',subNum,id,session);
    end
    input(['Data will be saved in ', dataFileName, ' (ENTER to continue)  ']);
else
    % in practice mode use dummy values
    subNum = 0;
    dataFileName = 'pracData';
end
end



%%%%
% function to generate target stimuli
function [digit, color, colorRGB, corResp] = genTarg(switchProb,digit,color,allowedResps)
% Inputs:
%   switchProb is the probability of switching tasks (colors) relative to
%       the previous trial
%   digit is the previous trial's digit (it will not be repeated)
%   color is the previous trial's color (indexed, 1 or 2)
%   allowedResps holds the actual keys associated with left and right
%       responses

availableColors = {[100, 100, 254]; [151, 151, 23]}; % RGB (1=blue, 2=yellow)
availableDigits = '12346789'; % 1-9 excluding 5

% select a non-repeating digit
prev_digit = digit;
while prev_digit==digit
    digit = availableDigits(randi(8));
end

% switch colors probabilistically, based on the switchProb arg
if rand<switchProb, color = 3-color; end

% identify the correct response
isLow = color==1 && str2double(digit)<5; % "low" is correct response
isOdd = color==2 && mod(str2double(digit),2)==1; % "odd" is correct response
if isLow || isOdd
    corResp = allowedResps.left;
else
    corResp = allowedResps.right;
end

% set the RGB color parameters
colorRGB = availableColors{color};

end



%%%%
% function to load stimulus graphics
function [stimTex, homeTex, fieldTex, digitTex, fbackTex] = loadStims(wid,bkgd,prac,ground,homeSz,fbackSz)
% load fractal images, which are 128 pixel squares; put them on fields of
% width specified by 'ground'. Also draw a couple other visual elements.
% Inputs:
%   wid - identifier of onscreen window
%   bkgd - screen background color
%   prac - 'p' if in practice mode (empty otherwise)
%   ground - width of squares on which stims are drawn
%   homeSz - width of the home-position cue
%   fbackSz - size of the feedback cues
% Outputs (all texture handles):
%   stimTex - nRuns x 2 matrix of location cues
%       each row holds the two cues shown in 1 run
%   homeTex - texture handle for the 'home position' cue
%   fieldTex - texture for the partially transparent gray field that will
%       be overlaid on a location before drawing the target digit.
%   digitTex - struct with identical textures in digit.easy and digit.hard
%       these are transparent, and will have digits drawn on each trial
%   fbackTex - struct with symbols for marking correct and incorrect
%       responses (used during the practice session only)

% load images of location marker stimuli
field = 128;
margin = (ground-field)/2;
fieldB = margin+1; % first pixel of the drawn stimulus
fieldE = ground-margin; % last pixel
stim_names = {  'abst01a', 'abst01b'
                'abst02a', 'abst02b'
                'abst03a', 'abst03b'
                'abst04a', 'abst04b'
                'abst05a', 'abst05b'
                'abst06a', 'abst06b'
                'abst07a', 'abst07b'
                'abst08a', 'abst08b'};
            
% different location cues are used in the practice session
if nargin>0 && strcmp(prac,'p')
    stim_names = {'abstPa', 'abstPb'}; 
end

% create a texture for each location cue
stimTex = zeros(size(stim_names));
for i = 1:size(stim_names,1)
    for j = 1:size(stim_names,2)
        stimMat = bkgd*ones(ground,ground,3);
        stimMat(fieldB:fieldE,fieldB:fieldE,:) = imread(['colorStims/', stim_names{i,j}, '.bmp']);
        stimTex(i,j) = Screen('MakeTexture',wid,stimMat);
    end
end

% create a texture for the target field
% i.e., the gray field overlaid on the location marker, as a backdrop
% for the digit
fieldMat = zeros(ground); % opacity of background
R_in = ceil(field*5/16); % radius of inner field where number is shown
R_out = ceil(field*7/16); % outer radius of faded ring around the field
for x = 1:ground
    for y = 1:ground
        r = sqrt(abs(x-ground/2)^2+abs(y-ground/2)^2);
        if r<R_in % if in the inner field
            fieldMat(x,y) = 1;
        elseif r<R_out % if in the faded ring around the field
            fieldMat(x,y) = (R_out-r)/(R_out-R_in);
        end % pixels outside the ring will remain at zero
    end
end
% full rgba matrix (previous fieldMat becomes the alpha layer)
fieldMat = cat(3,bkgd*ones(ground,ground,3),fieldMat*255); 
fieldTex = Screen('MakeTexture',wid,fieldMat);

% create blank and transparent textures for digits
targTextSize = 48;
digitMat = zeros(ground,ground,4);
for i = {'easy', 'hard'}
    digitTex.(i{1}) = Screen('MakeTexture',wid,digitMat);
    Screen('TextSize',digitTex.(i{1}),targTextSize);
end

% create a texture for the home cue (a bullseye
homeMat = ones(homeSz,homeSz,3)*bkgd;
white = 255;
black = 0;
for x = 1:homeSz
    for y = 1:homeSz
        if sqrt(power(abs(x-homeSz/2),2)+power(abs(y-homeSz/2),2))<8 %white circle
            homeMat(x,y,:) = white;
        end
        if sqrt(power(abs(x-homeSz/2),2)+power(abs(y-homeSz/2),2))<5.5 %black circle
            homeMat(x,y,:) = black;
        end
        if sqrt(power(abs(x-homeSz/2),2)+power(abs(y-homeSz/2),2))<2 %white center
            homeMat(x,y,:) = white;
        end
    end
end
homeTex = Screen('MakeTexture',wid,homeMat);

% create textures for feedback symbols (used in practice session only)
fbackMat.yes = ones(fbackSz,fbackSz,3)*bkgd;
fbackMat.no = ones(fbackSz,fbackSz,3)*bkgd;
for x = 1:fbackSz
    for y = 1:fbackSz
        if sqrt(power(abs(x-25),2)+power(abs(y-25),2))<25 % a solid circle
            fbackMat.yes(x,y,:) = [20, 160, 20];
        end
        if ismember(x,(y-5):(y+5)) || ismember(50-x,(y-5):(y+5)) % an X shape
            fbackMat.no(x,y,:) = [160, 50, 50];
        end
    end
end
for i = {'yes', 'no'}
    fbackMat.(i{1})(:,:,4) = 255; % define alpha layer to be opaque
    fbackTex.(i{1}) = Screen('MakeTexture',wid,fbackMat.(i{1}));
end

end



%%%%
% function to present isolated task-switching practice trials
function [] = ts_prac(wid,bkgd,centerRect,fbackRect,digitTex,fbackTex,allowedResps)

% initialize
digit = 0;
color = 1;
ground = RectHeight(centerRect);
targetTex = digitTex.easy; % either .easy or .hard would work fine

% intro screen
% experimenter presses '0' to move past this screen
displayMessage(wid,bkgd,'Ready to practice.',' ','0','');

% step 1: block of numbers with feedback shown after each
% at the end of this block, the experimenter may press either '0' to
% continue on, or '1' to repeat this part of practice. 
nTrials = 20;
goOn = 0;
while goOn==0
    WaitSecs(1);
    accuracy = zeros(nTrials,1);
    for t = 1:nTrials
        % switch tasks with probability 0.5
        [digit, color, colorRGB, corResp] = genTarg(0.5,digit,color,allowedResps);
        Screen('FillRect',targetTex,[0, 0, 0, 0]); % clear texture
        DrawFormattedText(targetTex,digit,'center',ground/2-30,[colorRGB, 255]);
        Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
        [resp, rt, accuracy(t,1)] = showTsTrial(wid,targetTex,centerRect,corResp,allowedResps,fbackTex,fbackRect);
        
        % blank ITI
        Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
        Screen('Flip',wid);
        showITI(wid);
        
    end
    % show summary feedback screen
    msg = sprintf('%d of %d correct. Pause here.',sum(accuracy),nTrials);
    resp = displayMessage(wid,bkgd,msg,'','01','');
    % experimenter may enter 0 (go on) or 1 (repeat)
    if ismember('0',resp), goOn = 1; end
end

% step 2: multiple short blocks of numbers
% no feedback on individual trials
% summary accuracy feedback at the end of each block
nBlocks = 6;
nPerBlock = 10;
goOn = 0;
while goOn==0
    WaitSecs(1);
    accuracy = zeros(nBlocks,nPerBlock);
    for b = 1:nBlocks
        for t = 1:nPerBlock
            % switch tasks with probability 0.5
            [digit, color, colorRGB, corResp] = genTarg(0.5,digit,color,allowedResps);
            Screen('FillRect',targetTex,[0, 0, 0, 0]); % clear texture
            DrawFormattedText(targetTex,digit,'center',ground/2-30,[colorRGB, 255]);
            Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
            [resp, rt, accuracy(b,t)] = showTsTrial(wid,targetTex,centerRect,corResp,allowedResps);

            % blank ITI
            Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
            Screen('Flip',wid);
            showITI(wid);
        end
        % single-block feedback
        msg = sprintf('%d of %d correct.',sum(accuracy(b,:)),nPerBlock);
        Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
        DrawFormattedText(wid,msg,'center','center',255);
        Screen('Flip',wid);
        Screen('FillRect',wid,[bkgd*ones(1,3), 255]); % clear screen
        WaitSecs(1);
        Screen('Flip',wid);
        WaitSecs(1);
    end
    % overall feedback
    msg = sprintf('Total: %d of %d correct. Pause here.',sum(accuracy(:)),nBlocks*nPerBlock);
    resp = displayMessage(wid,bkgd,msg,'','0123456789','');
    % experimenter enters the number of additional blocks to perform
    % (0 means go on)
    if ismember('0',resp), goOn = 1; end
    for i = 1:9
        if ismember(num2str(i),resp), nBlocks = i; end
    end
end

end



%%%%
% function to show a task-switching trial
% this is used both in the practice session and the main experiment
% digit responses are self-paced
% accuracy feedback will be shown iff fbackLoc is provided
function [resp, rt, accurate, targOnset] = showTsTrial(wid,tex,rect,corResp,allowedResps,fbTex,fbLoc)

% display the digit
Screen('DrawTexture',wid,tex,[],rect);
targOnset = Screen('Flip',wid,[],1);
% get the response to the digit
% check both the mouse and keyboard
responded = 0;
while responded==0
    % check both keyboard and mouse
    [keyIsDown, secs, keyCode] = KbCheck;
    [x, y, buttons] = GetMouse(wid);
    
    if keyIsDown==1 || any(buttons>0) 
        % a response has just occurred
        resp = [KbName(keyCode), num2str(find(buttons))];
        if any(ismember(resp,[allowedResps.left, allowedResps.right]))
            % response was allowable
            responded = 1;
        end
    end
    WaitSecs(.001);
end
% compute RT
rt = secs-targOnset;
% evaluate accuracy
if any(ismember(resp,corResp))
    accurate = 1;
else
    accurate = 0;
end
% show feedback if requested
% (do this if the 6th-7th args, fbTex and fbLoc are provided)
if nargin>5
    if accurate==1, fTex = fbTex.yes; else fTex = fbTex.no; end
    Screen('DrawTexture',wid,fTex,[],fbLoc);
    Screen('Flip',wid,[],1);
    WaitSecs(.25);
end

end



%%%%
% function for the inter-trial interval
function [] = showITI(wid)

WaitSecs(.25);

% stay in the ITI until all mouse buttons are released
buttons = [1, 1, 1];
while any(buttons);
    [x, y, buttons] = GetMouse(wid);
    WaitSecs(.001);
end
            
end





