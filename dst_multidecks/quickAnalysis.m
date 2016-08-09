function [] = quickAnalysis(dfname)
% prints basic summary statistics for one subject in the DST

% results are stored in a struct called 'data', set up as follows:
% 
% data.runNumber = nan(nRows,1);
% data.trialNumber = nan(nRows,1);
% data.easyRect = cell(nRows,1); % rectangle for position of the easy option
% data.hardRect = cell(nRows,1); % rectangle for position of the hard option
% data.choiceOnset = nan(nRows,1); % onset timestamp
% data.choiceRT = nan(nRows,1); % choice response latency
% data.choice = nan(nRows,1); % participant's selection: 1 = easy, 2 = hard
% data.targetColor = nan(nRows,1); % color of the number: 1 = blue, 2 = yellow
% data.targetDigit = nan(nRows,1);
% data.targetOnset = nan(nRows,1); % onset timestamp
% data.targetRT = nan(nRows,1); % response latency to the number
% data.targetResponse = cell(nRows,1); % which key was pressed
% data.targetAccuracy = nan(nRows,1); % response accuracy

% load data (assuming it is stored in the current directory)
d = load(dfname);

% basic info
nTrials = size(d.data.runNumber,1);
nRuns = max(d.data.runNumber);
nTrialsPerRun = max(d.data.trialNumber);
fprintf('\nresults summary for subject %d, id = %s:\n',d.dataHeader.subjectNumber,d.dataHeader.subjectID);
fprintf('%d runs, %d trials per run, %d trials total\n',nRuns,nTrialsPerRun,nTrials);

% choice rates
choiceRateTotal = mean(d.data.choice==1);
choiceRateByRun = zeros(nRuns,1);
for r=1:nRuns, choiceRateByRun(r) = mean(d.data.choice(d.data.runNumber==r)==1); end
fprintf('low-demand choice rate:\n\toverall: %1.2f\n',choiceRateTotal);
fprintf('\tby run: ');
fprintf('%1.2f ',choiceRateByRun);
fprintf('\n');

% RT, accuracy, and numbers of trials
% identify task-switch and task-repetition trials
taskSwitch = zeros(nTrials,1);
taskSwitch(2:end) = d.data.targetColor(2:end)~=d.data.targetColor(1:(end-1));
taskRepeat = ~taskSwitch;
% first trial in a run is considered neither a switch nor a repetition
firstTrial = d.data.trialNumber==1;
taskSwitch(firstTrial) = 0;
taskRepeat(firstTrial) = 0;
% index the demand-level condition
loDemand = d.data.choice==1;
hiDemand = d.data.choice==2;
% index 5 categories of trials:
% (1) all, (2) low-demand repeat, (3) low-demand switch, (4) high-demand
% repeat, (5) high-demand switch
indices = true(nTrials,5);
indices(:,2) = loDemand & taskRepeat;
indices(:,3) = loDemand & taskSwitch;
indices(:,4) = hiDemand & taskRepeat;
indices(:,5) = hiDemand & taskSwitch;
% use these indices to get the following:
% total number of trials, accuracy rate, and median RT
n = zeros(1,5);
accuracy = zeros(1,5);
rt = zeros(1,5);
for i = 1:5
    n(i) = sum(indices(:,i));
    accuracy(i) = mean(d.data.targetAccuracy(indices(:,i)));
    rt(i) = median(d.data.targetRT(indices(:,i)));
end
fprintf('accuracy and RT:\n');
fprintf('        \tall     \tloDem+Rp\tloDem+Sw\thiDem+Rp\thiDem+Sw\n'); % column headers
fprintf('n trials\t'); fprintf('%d\t\t',n); fprintf('\n'); % num trials
fprintf('accuracy\t'); fprintf('%1.2f\t\t',accuracy); fprintf('\n'); % accuracy
fprintf('rt      \t'); fprintf('%1.0fms\t\t',rt*1000); fprintf('\n'); % rt


