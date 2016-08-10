function [] = quickAnalysis(datafilename)
%QUICKANALYSIS shows plots for decks_math

load(datafilename) %establishes a struct called data

% compute statistics
maxRunLength=max(data.trialNum);
choicePlot=zeros(maxRunLength,2); %rows are trial numbers, cols hold the number of low and high demand selections
for i=1:maxRunLength
    choicePlot(i,1)=sum(data.choice(data.trialNum==i)==1); %low-demand count
    choicePlot(i,2)=sum(data.choice(data.trialNum==i)==2); %high-demand count
end
nRuns=max(data.runNum);
runChoiceRates=zeros(nRuns,1); %holds proportion low-demand choices in each run
for i=1:nRuns
    runChoiceRates(i)=sum(data.choice(data.runNum==i)==1)/sum(data.runNum==i);
end
rt=[0 0]; %holds median correct RT on low and high demand alternatives, respectively
rt(1)=median(data.targRT(data.choice==1 & data.targAcc==1));
rt(2)=median(data.targRT(data.choice==2 & data.targAcc==1));
ac=[0 0]; %holds accuracy rates for low and high demand alternatives
ac(1)=mean(data.targAcc(data.choice==1));
ac(2)=mean(data.targAcc(data.choice==2));

% display plots
figure(1); % choice rates
subplot(1,2,1); % choices over the course of a run
plot(choicePlot,'-','LineWidth',2);
xlabel('trial number'); ylabel('number of selections');
legend('low demand','high demand');
subplot(1,2,2); % choice proportions by run
hold on;
bar(runChoiceRates);
plot([.5 nRuns+.5],[.5 .5],'k--','LineWidth',1);
hold off;
xlabel('run number'); ylabel('proportion low-demand choices');
axis([.5 nRuns+.5 0 1]);

figure(2); % performance metrics
subplot(1,2,1); % accuracy
plot([1 2],ac,'o','LineWidth',2);
set(gca,'XTick',[1 2]);
set(gca,'XTickLabel',{'low demand' 'high demand'});
ylabel('proportion correct')
axis([.5 2.5 0 1]);
subplot(1,2,2);
plot([1 2],rt,'o','LineWidth',2);
set(gca,'XTick',[1 2]);
set(gca,'XTickLabel',{'low demand' 'high demand'});
ylabel('median RT (s)');
set(gca,'XLim',[.5 2.5]);