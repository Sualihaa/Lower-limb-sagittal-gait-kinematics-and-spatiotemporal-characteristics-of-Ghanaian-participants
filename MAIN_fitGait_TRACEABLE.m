% function MAIN_fitGait_TRACEABLE
% =========================================================================
%  / FMOISSENET-STYLE TRACEABLE PIPELINE
% =========================================================================
% Purpose:
%   Fit sagittal gait kinematics using Fmoissenet PatternGenerator functions,
%   but run the model separately for Ankle, Knee, and Hip so outputs do not
%   get mixed.
%
% Original reference:
%   Fmoissenet PatternGenerator MAIN_fitGait_v2.m
%
% Main changes from original:
%   1. Uses our Data_OURS/Norm_V1.mat ... Norm_V3.mat files.
%   2. Calculates Froude velocity limits from our own data.
%   3. Runs Ankle, Knee, and Hip separately.
%   4. Saves joint-specific Sort/Fitting/Regression/Predictors files.
%   5. Exports traceable CSV tables and figures.
%   6. Removes hard-coded Fmoissenet subject-33 correction.
%   7. Removes misleading bottom sections where Hip/Knee/Ankle used the
%      same one-joint model.
%
% Requirements:
%   This file must be placed in:
%       C:\Users\USER\Documents\fmoissenet-PatternGenerator-2315600
%
%   Required helper functions already from Fmoissenet:
%       extractData.m
%       prepareData.m
%       computeMean.m
%       discretePoints.m
%       quinticSpline.m
%       computeRegression.m
%       applyRegression.m
%       corridor.m
%
%   Required helper we added:
%       aa_set_vf_limits_from_norm_files.m
%
% Run:
%   MAIN_fitGait_AHENEMA_TRACEABLE
% =========================================================================

clearvars;
clc;
warning('off','all');

% -------------------------------------------------------------------------
% 0. PATHS
% -------------------------------------------------------------------------
rootDir = 'C:\Users\USER\Documents\fmoissenet-PatternGenerator-2315600';
dataDir = 'C:\Users\USER\Documents\multipleregression_datadescriptor\Data_OURS';

cd(rootDir);
addpath(rootDir);
addpath(dataDir);

resultsDir = fullfile(rootDir,'Results_AHENEMA_TRACEABLE');
figDir     = fullfile(resultsDir,'Figures');
matDir     = fullfile(resultsDir,'MAT');
csvDir     = fullfile(resultsDir,'CSV');

ensureFolder(resultsDir);
ensureFolder(figDir);
ensureFolder(matDir);
ensureFolder(csvDir);

diary(fullfile(resultsDir,'RunTrace_MAIN_fitGait_AHENEMA_TRACEABLE.txt'));
fprintf('\n============================================================\n');
fprintf('AHENEMA FMOISSENET-STYLE TRACEABLE RUN\n');
fprintf('Started: %s\n', datestr(now));
fprintf('============================================================\n\n');

% -------------------------------------------------------------------------
% 1. CONSTANTS
% -------------------------------------------------------------------------
N = 24;       % number of subjects in our dataset
C = 30;       % maximum cycles per subject; keep high enough
V = 3;        % our files: Norm_V1, Norm_V2, Norm_V3
T = 101;      % gait cycle frames
stepVf = 0.05;
pReg = 0.01;

% Selected regression model:
%   X = [walking speed, age, sex, BMI]
%   plus constant term handled by computeRegression.
correlations = {'Constant','Walking speed','Age','Sex','BMI'};

fprintf('N subjects: %d\n', N);
fprintf('V speed-condition files: %d\n', V);
fprintf('T frames: %d\n', T);
fprintf('Predictors: Walking speed, Age, Sex, BMI\n');
fprintf('Sex coding: 0 = Female, 1 = Male\n\n');

% -------------------------------------------------------------------------
% 2. LOAD OUR FMOISSENET-STYLE NORM FILES DIRECTLY
% -------------------------------------------------------------------------
File(1) = load(fullfile(dataDir,'Norm_V1.mat'));
File(2) = load(fullfile(dataDir,'Norm_V2.mat'));
File(3) = load(fullfile(dataDir,'Norm_V3.mat'));

fprintf('Loaded files:\n');
fprintf('  %s\n', fullfile(dataDir,'Norm_V1.mat'));
fprintf('  %s\n', fullfile(dataDir,'Norm_V2.mat'));
fprintf('  %s\n', fullfile(dataDir,'Norm_V3.mat'));

% DO NOT use Fmoissenet's original correction:
%   File(i).Population.height.data(33) = 1.8;
% because our dataset has 24 subjects, not 52.

% -------------------------------------------------------------------------
% 3. CALCULATE FROUDE VELOCITY LIMITS FROM OUR DATA
% -------------------------------------------------------------------------
[minVf, maxVf, stepVf, vfPlotMax, vfStats] = ...
    aa_set_vf_limits_from_norm_files(File, V, stepVf);

save(fullfile(matDir,'Vf_Settings.mat'), ...
    'minVf','maxVf','stepVf','vfPlotMax','vfStats');

VfSummary = struct2table(rmfield(vfStats,'values'));
writetable(VfSummary, fullfile(csvDir,'Vf_Settings.csv'));

fprintf('\nSaved Vf settings.\n');
fprintf('minVf = %.2f | maxVf = %.2f | vfPlotMax = %.2f | stepVf = %.2f\n\n', ...
    minVf, maxVf, vfPlotMax, stepVf);

% -------------------------------------------------------------------------
% 4. BUILD SUBJECT/CYCLE INDICES USED BY FMOISSENET FUNCTIONS
% -------------------------------------------------------------------------
[icycle,isubject] = buildSubjectCycleIndices(File,N,C,V);

save(fullfile(matDir,'SubjectCycleIndices.mat'), 'icycle','isubject');

fprintf('Built subject-cycle indices.\n\n');

% -------------------------------------------------------------------------
% 5. DEFINE JOINTS
% -------------------------------------------------------------------------
Joint(1).name = 'Ankle';
Joint(1).code = 'FE2';
Joint(1).sign = 1;
Joint(1).ylabel = 'Ankle DF(+)/PF (°)';
Joint(1).ylimValidationRMSE = [0 14];
Joint(1).ylimPredictor = [-20 20];

Joint(2).name = 'Knee';
Joint(2).code = 'FE3';
Joint(2).sign = -1;
Joint(2).ylabel = 'Knee Flex(+)/Ext (°)';
Joint(2).ylimValidationRMSE = [0 18];
% Joint(2).ylimPredictor = [-5 70];
Joint(2).ylimPredictor = [0 80];

Joint(3).name = 'Hip';
Joint(3).code = 'FE4';
Joint(3).sign = 1;
Joint(3).ylabel = 'Hip Flex(+)/Ext (°)';
Joint(3).ylimValidationRMSE = [0 14];
Joint(3).ylimPredictor = [-25 35];

% IMPORTANT:
% We now run all joints separately.
% This prevents Hip/Knee/Ankle plots from sharing the same one-joint model.
jointList = 1:3;

% Choose whether to remove the first-frame offset.
% false = keep absolute joint angles.
% true  = analyse curve shape relative to first frame.
removeInitialOffset = false;

% -------------------------------------------------------------------------
% 6. RUN MODEL FOR EACH JOINT
% -------------------------------------------------------------------------
RunSummary = table();

for jj = 1:numel(jointList)

    J = jointList(jj);
    jointName = Joint(J).name;

    fprintf('\n============================================================\n');
    fprintf('RUNNING JOINT: %s | code: %s | J = %d\n', ...
        jointName, Joint(J).code, J);
    fprintf('============================================================\n');

    [Sort, Fit, Reg, Predictors, Mean, Population, Validation] = ...
        runOneJointModel(File, Joint, J, icycle, isubject, ...
        N, V, T, minVf, maxVf, stepVf, pReg, correlations, removeInitialOffset, csvDir);

    % ---------------------------------------------------------------------
    % 6A. SAVE JOINT-SPECIFIC MAT FILES
    % ---------------------------------------------------------------------
    save(fullfile(matDir,sprintf('Sort_%s.mat',jointName)), 'Sort');
    save(fullfile(matDir,sprintf('Fitting_%s.mat',jointName)), 'Fit');
    save(fullfile(matDir,sprintf('Regression_%s.mat',jointName)), 'Reg');
    save(fullfile(matDir,sprintf('Predictors_%s.mat',jointName)), 'Predictors');
    save(fullfile(matDir,sprintf('Population_%s.mat',jointName)), 'Population','Mean');
    save(fullfile(matDir,sprintf('Validation_%s.mat',jointName)), 'Validation');

    % Also save conventional filenames for compatibility with original code.
    save('Sort.mat','Sort');
    save('Fitting.mat','Fit');
    save('Regression.mat','Reg');
    save('Predictors.mat','Predictors');
    save('Population.mat','Population','Mean');

    % ---------------------------------------------------------------------
    % 6B. EXPORT PREDICTOR TABLE
    % ---------------------------------------------------------------------
    predTable = predictorsToTable(Predictors, jointName);
    writetable(predTable, fullfile(csvDir,sprintf('Predictors_%s.csv',jointName)));

    % ---------------------------------------------------------------------
    % 6C. EXPORT VALIDATION TABLE
    % ---------------------------------------------------------------------
    valTable = validationToTable(Validation, jointName);
    writetable(valTable, fullfile(csvDir,sprintf('Validation_%s.csv',jointName)));

    % ---------------------------------------------------------------------
    % 6D. PLOT VALIDATION SUMMARY
    % ---------------------------------------------------------------------
    figVal = plotValidationSummary(Validation, Population, Joint, J, ...
        minVf, stepVf, vfPlotMax);
    saveCurrentFigureLocal(figVal, figDir, sprintf('%s_validation_summary',jointName));
    close(figVal);

    % ---------------------------------------------------------------------
    % 6E. PLOT PREDICTOR CONTRIBUTION FOR THIS JOINT ONLY
    % ---------------------------------------------------------------------
    figPred = plotPredictorContributionForJoint(Sort, Predictors, Joint, J, ...
        minVf, maxVf, stepVf);
    plotRawFitRegressionCheck(Sort, Fit, Reg, Joint, J, figDir);
    saveCurrentFigureLocal(figPred, figDir, sprintf('%s_predictor_contribution',jointName));
    close(figPred);

    % ---------------------------------------------------------------------
    % 6F. SUMMARY ROW
    % ---------------------------------------------------------------------
    allRMSE = [];
    allR2 = [];
    allVAF = [];

    for s = 1:numel(Validation)
        if isfield(Validation(s),'RMSE')
            allRMSE = [allRMSE Validation(s).RMSE]; %#ok<AGROW>
        end
        if isfield(Validation(s),'R2')
            allR2 = [allR2 Validation(s).R2]; %#ok<AGROW>
        end
        if isfield(Validation(s),'VAF')
            allVAF = [allVAF Validation(s).VAF]; %#ok<AGROW>
        end
    end

    newRow = table( ...
        string(jointName), ...
        mean(allRMSE,'omitnan'), std(allRMSE,0,'omitnan'), ...
        mean(allR2,'omitnan'), std(allR2,0,'omitnan'), ...
        mean(allVAF,'omitnan'), std(allVAF,0,'omitnan'), ...
        size(Sort.kinematics,2), ...
        'VariableNames', {'Joint','RMSE_mean','RMSE_std','R2_mean','R2_std','VAF_mean','VAF_std','NCycles'} ...
        );

    RunSummary = [RunSummary; newRow]; %#ok<AGROW>

    fprintf('Finished %s.\n', jointName);
    fprintf('  cycles used: %d\n', size(Sort.kinematics,2));
    fprintf('  validation RMSE mean: %.3f deg\n', mean(allRMSE,'omitnan'));
    fprintf('  validation R2 mean: %.3f\n', mean(allR2,'omitnan'));
    fprintf('  validation VAF mean: %.3f %%\n', mean(allVAF,'omitnan'));
end

writetable(RunSummary, fullfile(csvDir,'RunSummary_AllJoints.csv'));
save(fullfile(matDir,'RunSummary_AllJoints.mat'), 'RunSummary');

fprintf('\n============================================================\n');
fprintf('ALL JOINTS FINISHED\n');
fprintf('Outputs saved in:\n');
fprintf('  %s\n', resultsDir);
fprintf('Finished: %s\n', datestr(now));
fprintf('============================================================\n');

diary off;



%% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================

function ensureFolder(folderPath)
if ~exist(folderPath,'dir')
    mkdir(folderPath);
end
end

function [icycle,isubject] = buildSubjectCycleIndices(File,N,C,V)
% Build the subject-cycle indexing arrays expected by extractData.
% This replaces the original Fmoissenet special-case indexing for specific
% subject positions. Our dataset uses anonymised subject codes and does not
% need those special cases.

icycle = nan(N,C,V);
isubject = nan(1000,V);

for v = 1:V

    sujets = File(v).Normatives.Kinematics.sujets;

    % Convert to cellstr for robust strcmp behaviour.
    sujets = cellstr(string(sujets));

    uniqueNames = unique(sujets,'stable');

    for n = 1:min(N,numel(uniqueNames))
        idx = find(strcmp(sujets,uniqueNames{n}));
        nCycles = min(numel(idx),C);
        icycle(n,1:nCycles,v) = idx(1:nCycles);
    end

    temp = nan(numel(sujets),1);
    for i = 1:numel(sujets)
        temp(i) = find(strcmp(uniqueNames,sujets{i}),1,'first');
    end

    isubject(1:numel(temp),v) = temp;
end
end

function [Sort, Fit, Reg, Predictors, Mean, Population, Validation] = ...
    runOneJointModel(File, Joint, J, icycle, isubject, ...
    N, V, T, minVf, maxVf, stepVf, pReg, correlations, removeInitialOffset, csvDir)

% -------------------------------------------------------------------------
% TRAINING ON ALL SUBJECTS
% -------------------------------------------------------------------------
rsubject = 0;
subject_sub = 1:N;

% Raw = extractData(File,Joint,icycle,isubject,subject_sub,rsubject,N,V,T,J,'training');
% Sort = prepareData(Raw,minVf,maxVf);
% 
% if removeInitialOffset
%     Sort = subtractInitialFrame(Sort);
% end

Raw = extractData(File,Joint,icycle,isubject,subject_sub,rsubject,N,V,T,J,'training');
Sort = prepareData(Raw,minVf,maxVf);

% knee to use the convention: flexion positive, extension lower/near zero.
Sort = enforceKneeFlexionPositive(Sort, Joint, J, 'all-subject training');

if removeInitialOffset
    Sort = subtractInitialFrame(Sort);
end
[Mean,Population] = computeMean(Sort,minVf,maxVf,stepVf);

Fit = struct();
for i = 1:size(Sort.kinematics,2)
    Fit.DP(:,:,i) = discretePoints(Joint(J).code,Sort.kinematics(:,i), ...
        [Sort.IFS1(:,i); Sort.IFS2(:,i)],Sort.IFO(:,i),Sort.CFS(:,i),Sort.CFO(:,i),0);
end

for i = 1:size(Sort.kinematics,2)
    Fit.kinematics(:,i) = quinticSpline(Fit.DP(:,:,i),0);
end

X = [Sort.walkingSpeed' Sort.age' Sort.sex' Sort.BMI'];
[Reg.DP,Predictors] = computeRegression(X,Fit.DP,correlations,pReg,0);

for i = 1:size(Sort.kinematics,2)
    Reg.kinematics(:,i) = quinticSpline(Reg.DP(:,:,i),0);
end

% -------------------------------------------------------------------------
% LEAVE-ONE-SUBJECT-OUT VALIDATION
% -------------------------------------------------------------------------
Validation = struct();
KeypointErrorRows = table();
s = 1;

for rsubject = 1:N

    fprintf('  Removed subject: %d\n', rsubject);

    if rsubject == 1
        subject_train = 2:N;
    elseif rsubject == N
        subject_train = 1:N-1;
    else
        subject_train = [1:rsubject-1 rsubject+1:N];
    end

    % ------------------------------
    % Training set
    % ------------------------------
    % RawTrain = extractData(File,Joint,icycle,isubject,subject_train,rsubject,N,V,T,J,'training');
    % SortTrain = prepareData(RawTrain,minVf,maxVf);
    % 
    % if removeInitialOffset
    %     SortTrain = subtractInitialFrame(SortTrain);
    % end
    RawTrain = extractData(File,Joint,icycle,isubject,subject_train,rsubject,N,V,T,J,'training');
    SortTrain = prepareData(RawTrain,minVf,maxVf);
    
    SortTrain = enforceKneeFlexionPositive(SortTrain, Joint, J, ...
        sprintf('LOSO training, removed subject %d', rsubject));
    
    if removeInitialOffset
        SortTrain = subtractInitialFrame(SortTrain);
    end
    FitTrain = struct();
    for i = 1:size(SortTrain.kinematics,2)
        FitTrain.DP(:,:,i) = discretePoints(Joint(J).code,SortTrain.kinematics(:,i), ...
            [SortTrain.IFS1(:,i); SortTrain.IFS2(:,i)], ...
            SortTrain.IFO(:,i),SortTrain.CFS(:,i),SortTrain.CFO(:,i),0);
    end

    for i = 1:size(SortTrain.kinematics,2)
        FitTrain.kinematics(:,i) = quinticSpline(FitTrain.DP(:,:,i),0);
    end

    XTrain = [SortTrain.walkingSpeed' SortTrain.age' SortTrain.sex' SortTrain.BMI'];
    [~,PredictorsTrain] = computeRegression(XTrain,FitTrain.DP,correlations,pReg,0);

    % ------------------------------
    % Testing set
    % ------------------------------
    % RawTest = extractData(File,Joint,icycle,isubject,subject_train,rsubject,N,V,T,J,'testing');
    % SortTest = prepareData(RawTest,minVf,maxVf);
    % 
    % if removeInitialOffset
    %     SortTest = subtractInitialFrame(SortTest);
    % end
    RawTest = extractData(File,Joint,icycle,isubject,subject_train,rsubject,N,V,T,J,'testing');
    SortTest = prepareData(RawTest,minVf,maxVf);
    
    SortTest = enforceKneeFlexionPositive(SortTest, Joint, J, ...
        sprintf('LOSO testing, removed subject %d', rsubject));
    
    if removeInitialOffset
        SortTest = subtractInitialFrame(SortTest);
    end
    
    XTest = [SortTest.walkingSpeed' SortTest.age' SortTest.sex' SortTest.BMI'];

    RegTest = struct();
    RegTest.DP = applyRegression(XTest,PredictorsTrain);
    
    FitTest = struct();
    
    for i = 1:size(SortTest.kinematics,2)
    
        FitTest.DP(:,:,i) = discretePoints(Joint(J).code,SortTest.kinematics(:,i), ...
            [SortTest.IFS1(:,i); SortTest.IFS2(:,i)], ...
            SortTest.IFO(:,i),SortTest.CFS(:,i),SortTest.CFO(:,i),0);
    
        FitTest.kinematics(:,i) = quinticSpline(FitTest.DP(:,:,i),0);
        RegTest.kinematics(:,i) = quinticSpline(RegTest.DP(:,:,i),0);
    
        err = RegTest.kinematics(:,i) - SortTest.kinematics(:,i);
    
        Validation(s).SubjectRemoved = rsubject;
        Validation(s).Speed(i) = SortTest.walkingSpeed(:,i);
        Validation(s).RMSE(i) = sqrt(mean(err.^2));
        Validation(s).R2(i) = 1 - sum(err.^2) / ...
            sum((SortTest.kinematics(:,i)-mean(SortTest.kinematics(:,i),1)).^2);
        Validation(s).MAX(i) = max(abs(err));
        Validation(s).VAF(i) = (1 - var(err)/var(SortTest.kinematics(:,i))) * 100;
    
    end
    
    KeypointErrorRows = appendKeypointErrors( ...
        KeypointErrorRows, ...
        Joint(J).name, ...
        Joint(J).code, ...
        rsubject, ...
        FitTest.DP, ...
        RegTest.DP);

    s = s + 1;
end

    KeypointRMSE = computeKeypointRMSE(KeypointErrorRows);
    
    writetable(KeypointErrorRows, fullfile(csvDir, sprintf('Keypoint_Errors_%s.csv', Joint(J).name)));
    writetable(KeypointRMSE, fullfile(csvDir, sprintf('Keypoint_RMSE_%s.csv', Joint(J).name)));

end

function Sort = subtractInitialFrame(Sort)
for i = 1:size(Sort.kinematics,2)
    Sort.kinematics(:,i) = Sort.kinematics(:,i) - Sort.kinematics(1,i);
end
end

function fig = plotValidationSummary(Validation, Population, Joint, J, minVf, stepVf, vfPlotMax)

fig = figure('pos',[10 10 1100 300]);

jointLabel = Joint(J).ylabel;
k = 1;
population_mean = [];
population_std = [];

nPopBins = numel(Population.RMSE);
vf_values = minVf:stepVf:vfPlotMax;
vf_values = vf_values(1:min(numel(vf_values),nPopBins));

for vf = vf_values

    tempRMSE = [];
    tempR2 = [];
    tempVAF = [];

    for i = 1:numel(Validation)
        for j = 1:numel(Validation(i).Speed)
            if abs(Validation(i).Speed(j)-vf) < stepVf/2
                tempRMSE = [tempRMSE Validation(i).RMSE(j)]; %#ok<AGROW>
                tempR2   = [tempR2   Validation(i).R2(j)]; %#ok<AGROW>
                tempVAF  = [tempVAF  Validation(i).VAF(j)]; %#ok<AGROW>
            end
        end
    end

    % -------------------------------------------------------------
    % RMSE
    % -------------------------------------------------------------
    subplot(1,3,1);
    hold on;
    title('RMSE');
    ylabel('RMSE (°)');
    xlabel('Non-dimensionalised walking speed');
    box on;
    grid on;

    if ~isempty(tempRMSE)
        errorbar(vf,mean(tempRMSE,'omitnan'),std(tempRMSE,0,'omitnan'),'kx');
    end

    ylim(Joint(J).ylimValidationRMSE);

    if k <= numel(Population.RMSE)
        population_mean = [population_mean Population.RMSE(k).mean]; %#ok<AGROW>
        population_std  = [population_std  Population.RMSE(k).std]; %#ok<AGROW>
    end

    % -------------------------------------------------------------
    % R2
    % -------------------------------------------------------------
    subplot(1,3,2);
    hold on;
    title('R2');
    ylabel(strrep(jointLabel,' (°)',''));
    xlabel('Non-dimensionalised walking speed');
    box on;
    grid on;

    if ~isempty(tempR2)
        errorbar(vf,mean(tempR2,'omitnan'),std(tempR2,0,'omitnan'),'kx');
    end

    plot([0:0.1:0.8],0.3*ones(size([0:0.1:0.8])), ...
        'Linestyle','--','Color','black');
    plot([0:0.1:0.8],0.6*ones(size([0:0.1:0.8])), ...
        'Linestyle','--','Color','black');
    plot([0:0.1:0.8],0.9*ones(size([0:0.1:0.8])), ...
        'Linestyle','--','Color','black');

    ylim([0 1]);

    % -------------------------------------------------------------
    % VAF
    % -------------------------------------------------------------
    subplot(1,3,3);
    hold on;
    title('VAF');
    ylabel([strrep(jointLabel,' (°)','') ' (%)']);
    xlabel('Non-dimensionalised walking speed');
    box on;
    grid on;

    if ~isempty(tempVAF)
        errorbar(vf,mean(tempVAF,'omitnan'),std(tempVAF,0,'omitnan'),'kx');
    end

    plot([0:0.1:0.8],80*ones(size([0:0.1:0.8])), ...
        'Linestyle','--','Color','black');

    ylim([0 100]);

    k = k + 1;
end

% -------------------------------------------------------------
% Add population RMSE corridor on RMSE subplot
% -------------------------------------------------------------
subplot(1,3,1);
if ~isempty(population_mean)
    corridor(population_mean',population_std',minVf,stepVf, ...
        minVf + stepVf*(numel(population_mean)-1),'black');
end

% Correct title for validation figure
sgtitle(sprintf('%s leave-one-subject-out validation', Joint(J).name));

end

function fig = plotPredictorContributionForJoint(Sort, Predictors, Joint, J, minVf, maxVf, stepVf)

fig = figure('pos',[10 10 1450 420]);
fig.PaperSize = [20 6];

jointLabel = Joint(J).ylabel;
jointName = Joint(J).name;

% -------------------------------------------------------------------------
% Define predictor ranges
% -------------------------------------------------------------------------
pred(1).name = 'Walking speed';
pred(1).values = minVf:stepVf:maxVf;
pred(1).xLabel = 'Non-dimensionalised walking speed';
pred(1).tickLabels = makeTickLabels(pred(1).values);

pred(2).name = 'Age';
ageMin = floor(min(Sort.age));
ageMax = ceil(max(Sort.age));
if ageMin == ageMax
    pred(2).values = ageMin;
else
    pred(2).values = ageMin:1:ageMax;
end
pred(2).xLabel = 'Age (years)';
pred(2).tickLabels = makeTickLabels(pred(2).values);

pred(3).name = 'Sex';
pred(3).values = [0 1];
pred(3).xLabel = 'Sex';
pred(3).tickLabels = {'Female','Male'};

pred(4).name = 'BMI';
bmiMin = floor(min(Sort.BMI));
bmiMax = ceil(max(Sort.BMI));
if bmiMin == bmiMax
    pred(4).values = bmiMin;
else
    pred(4).values = bmiMin:1:bmiMax;
end
pred(4).xLabel = 'BMI (kg.m^{-2})';
pred(4).tickLabels = makeTickLabels(pred(4).values);

% -------------------------------------------------------------------------
% Plot each predictor panel
% -------------------------------------------------------------------------
for p = 1:4

    values = pred(p).values;
    nVals = numel(values);

    clear kin Test X

    for a = 1:nVals

        % Hold all other predictors at their median/reference values
        walkingSpeed = median(Sort.walkingSpeed,'omitnan');
        age = median(Sort.age,'omitnan');
        sex = median(Sort.sex,'omitnan');
        BMI = median(Sort.BMI,'omitnan');

        % Vary only the selected predictor
        if p == 1
            walkingSpeed = values(a);
        elseif p == 2
            age = values(a);
        elseif p == 3
            sex = values(a);
        elseif p == 4
            BMI = values(a);
        end

        X = [walkingSpeed age sex BMI];

        Test(a).DP = applyRegression(X,Predictors);
        kin(:,a) = quinticSpline(Test(a).DP,0);
    end

    h = subplot(1,4,p);
    hold on;
    box on;

    if p == 1
        ylabel(jointLabel);
    end

    title(pred(p).name);
    xlabel('Gait cycle (%)');

    % ---------------------------------------------------------------------
    % Grey corridor = range of predicted curves
    % ---------------------------------------------------------------------
    x = [1:1:101 101:-1:1]';
    pMax = max(kin,[],2);
    pMin = min(kin,[],2);
    y = [pMax; pMin(end:-1:1)];

    fill(x,y,'black', ...
        'LineStyle','none', ...
        'Facealpha',0.25);

    % ---------------------------------------------------------------------
    % Dashed black curve = median/reference predicted curve
    % ---------------------------------------------------------------------
    plot(median(kin,2,'omitnan'), ...
        'Linestyle','--', ...
        'Color','black', ...
        'LineWidth',1.5);

    % ---------------------------------------------------------------------
    % Coloured key-points
    % ---------------------------------------------------------------------
    D = jet(max(nVals,2));
    colormap(h,D);

    for a = 1:nVals
        for kp = 1:size(Test(a).DP,1)
            plot(Test(a).DP(kp,1),Test(a).DP(kp,2), ...
                'Marker','.', ...
                'Color',D(a,:), ...
                'Markersize',16);
        end
    end

    % ---------------------------------------------------------------------
    % Add significance/effect-size markers
    % p = 1 walking speed -> predictorIndex = 2
    % p = 2 age           -> predictorIndex = 3
    % p = 3 sex           -> predictorIndex = 4
    % p = 4 BMI           -> predictorIndex = 5
    % ---------------------------------------------------------------------
    predictorIndex = p + 1;
    addEffectMarkers(Test, Predictors, predictorIndex);

    % ---------------------------------------------------------------------
    % Axes and colour bar
    % ---------------------------------------------------------------------
    xlim([0 101]);
    ylim(Joint(J).ylimPredictor);

    cb = colorbar('Location','southoutside');
    cb.TickDirection = 'in';

    if p == 3
        caxis([0 1]);
        cb.Ticks = [0 1];
        cb.TickLabels = pred(p).tickLabels;
    else
        caxis([min(values) max(values)]);
        cb.Ticks = [min(values) median(values) max(values)];
        cb.TickLabels = makeTickLabels([min(values) median(values) max(values)]);
    end

    cb.Label.String = pred(p).xLabel;

end

% -------------------------------------------------------------------------
% Main title
% -------------------------------------------------------------------------
sgtitle(sprintf('%s predictor contribution', jointName));

% -------------------------------------------------------------------------
% Paper-style explanatory note under the figure
% -------------------------------------------------------------------------
legendText1 = ['Grey corridor = predicted waveform range; dashed black curve = median predicted waveform; ' ...
               'coloured dots = predicted key-points.'];

legendText2 = ['* angular amplitude 2°–5°; ** angular amplitude >5°; ' ...
               'x timing amplitude >3% of gait cycle.'];

annotation(fig,'textbox',[0.06 0.055 0.90 0.035], ...
    'String',legendText1, ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'FontSize',8, ...
    'Interpreter','none');

annotation(fig,'textbox',[0.06 0.015 0.90 0.035], ...
    'String',legendText2, ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'FontSize',8, ...
    'Interpreter','none');

end

function labels = makeTickLabels(values)
labels = cell(1,numel(values));
for i = 1:numel(values)
    if abs(values(i) - round(values(i))) < 1e-6
        labels{i} = sprintf('%d',round(values(i)));
    else
        labels{i} = sprintf('%.2f',values(i));
    end
end
end

function T = predictorsToTable(Predictors, jointName)

[nKeypoints,nParams,nPredictors] = size(Predictors);

defaultNames = {'Constant','Walking speed','Age','Sex','BMI'};
rows = {};
r = 1;

for kp = 1:nKeypoints
    for param = 1:nParams
        for p = 1:nPredictors

            if p <= numel(defaultNames)
                predName = defaultNames{p};
            else
                predName = sprintf('Predictor_%d',p);
            end

            value = getStructFieldSafe(Predictors(kp,param,p),'value');
            sig   = getStructFieldSafe(Predictors(kp,param,p),'significance');

            rows(r,:) = {jointName,kp,param,predName,value,sig}; %#ok<AGROW>
            r = r + 1;
        end
    end
end

T = cell2table(rows,'VariableNames', ...
    {'Joint','Keypoint','ParameterIndex','Predictor','Value','Significance'});

end

function T = validationToTable(Validation, jointName)

rows = {};
r = 1;

for s = 1:numel(Validation)
    subjectRemoved = Validation(s).SubjectRemoved;

    for i = 1:numel(Validation(s).Speed)
        rows(r,:) = { ...
            jointName, ...
            subjectRemoved, ...
            i, ...
            Validation(s).Speed(i), ...
            Validation(s).RMSE(i), ...
            Validation(s).R2(i), ...
            Validation(s).MAX(i), ...
            Validation(s).VAF(i) ...
            }; %#ok<AGROW>
        r = r + 1;
    end
end

T = cell2table(rows,'VariableNames', ...
    {'Joint','SubjectRemoved','CycleIndex','Speed','RMSE','R2','MAX','VAF'});

end

function x = getStructFieldSafe(S,fieldName)

if isstruct(S) && isfield(S,fieldName)
    x = S.(fieldName);
else
    x = NaN;
end

if isempty(x)
    x = NaN;
end

if isnumeric(x) && numel(x) > 1
    x = x(1);
elseif islogical(x)
    x = double(x);
elseif ischar(x) || isstring(x)
    x = string(x);
elseif ~isnumeric(x)
    x = NaN;
end

end

function saveCurrentFigureLocal(fig,outDir,baseName)

ensureFolder(outDir);

baseName = regexprep(baseName,'[^\w\-]','_');

figPath = fullfile(outDir,[baseName '.fig']);
pngPath = fullfile(outDir,[baseName '.png']);
tifPath = fullfile(outDir,[baseName '.tif']);
pdfPath = fullfile(outDir,[baseName '.pdf']);

savefig(fig,figPath);

try
    exportgraphics(fig,pngPath,'Resolution',300);
    exportgraphics(fig,tifPath,'Resolution',300);
    exportgraphics(fig,pdfPath,'ContentType','vector');
catch
    print(fig,pngPath,'-dpng','-r300');
    print(fig,tifPath,'-dtiff','-r300');
    print(fig,pdfPath,'-dpdf','-bestfit');
end

fprintf('Saved figure set:\n');
fprintf('  %s\n',figPath);
fprintf('  %s\n',pngPath);
fprintf('  %s\n',tifPath);
fprintf('  %s\n',pdfPath);

end


function plotRawFitRegressionCheck(Sort, Fit, Reg, Joint, J, figDir)

jointName = Joint(J).name;

fig = figure('pos',[10 10 1200 350]);

% Pick up to 20 representative cycles
nCycles = size(Sort.kinematics,2);
idx = round(linspace(1,nCycles,min(20,nCycles)));

subplot(1,3,1);
hold on; box on; grid on;
plot(Sort.kinematics(:,idx));
title([jointName ' raw Sort.kinematics']);
xlabel('Gait cycle (%)');
ylabel(Joint(J).ylabel);
xlim([1 101]);

subplot(1,3,2);
hold on; box on; grid on;
plot(Fit.kinematics(:,idx));
title([jointName ' fitted quintic splines']);
xlabel('Gait cycle (%)');
ylabel(Joint(J).ylabel);
xlim([1 101]);

subplot(1,3,3);
hold on; box on; grid on;
plot(Reg.kinematics(:,idx));
title([jointName ' regression reconstruction']);
xlabel('Gait cycle (%)');
ylabel(Joint(J).ylabel);
xlim([1 101]);

sgtitle([jointName ' raw-fit-regression diagnostic']);

saveCurrentFigureLocal(fig, figDir, [jointName '_raw_fit_regression_check']);
close(fig);

end

function Sort = enforceKneeFlexionPositive(Sort, Joint, J, contextLabel)
%ENFORCEKNEEFLEXIONPOSITIVE Ensures knee flexion is positive.
%
% Why:
%   The diagnostic showed raw knee Sort.kinematics had a large negative
%   swing-phase peak, even though the plot label is Knee Flex(+)/Ext.
%
% Rule:
%   If the median knee angle around swing phase, 60-80% gait cycle, is
%   negative, multiply the knee curves by -1.
%
% Trace:
%   Prints exactly what was done.

if ~strcmpi(Joint(J).name,'Knee')
    return;
end

swingWindow = 60:80;

medianSwing = median(Sort.kinematics(swingWindow,:), 'all', 'omitnan');

fprintf('  Knee sign check [%s]: median 60-80%% angle = %.3f deg\n', ...
    contextLabel, medianSwing);

if medianSwing < 0
    Sort.kinematics = -Sort.kinematics;
    fprintf('  ACTION [%s]: Knee curves multiplied by -1 so flexion is positive.\n', ...
        contextLabel);
else
    fprintf('  ACTION [%s]: Knee sign kept unchanged.\n', contextLabel);
end

end

function Terrors = appendKeypointErrors(Terrors, jointName, jointCode, removedSubject, DPtrue, DPpred)
%APPENDKEYPOINTERRORS Stores original vs predicted key-point errors.
%
% Assumes DP dimensions:
%   keypoint x parameter x cycle
%
% Parameter index:
%   1 = timing
%   2 = angle
%   3 = velocity
%   4 = acceleration
%
% For Table 2, we only export timing and angle.

parameterNames = {'Timing (% gait cycle)', 'Angle (deg)'};

nKeypoints = size(DPtrue,1);
nCycles = size(DPtrue,3);

newRows = table();

for kp = 1:nKeypoints
    for p = 1:2   % only timing and angle for main Table 2
        for c = 1:nCycles

            yTrue = DPtrue(kp,p,c);
            yPred = DPpred(kp,p,c);

            if isnan(yTrue) || isnan(yPred)
                continue;
            end

            err = yTrue - yPred;

            temp = table( ...
                string(jointName), ...
                string(sprintf('%s%d', jointCode, kp)), ...
                kp, ...
                string(parameterNames{p}), ...
                p, ...
                removedSubject, ...
                c, ...
                yTrue, ...
                yPred, ...
                err, ...
                err^2, ...
                'VariableNames', { ...
                    'Joint', ...
                    'Keypoint', ...
                    'KeypointIndex', ...
                    'Parameter', ...
                    'ParameterIndex', ...
                    'RemovedSubject', ...
                    'CycleIndex', ...
                    'OriginalValue', ...
                    'PredictedValue', ...
                    'Error', ...
                    'SquaredError'});

            newRows = [newRows; temp];

        end
    end
end

Terrors = [Terrors; newRows];

end

function Tout = computeKeypointRMSE(Terrors)
%COMPUTEKEYPOINTRMSE Calculates RMSE for each key-point parameter.

groups = unique(Terrors(:, {'Joint','Keypoint','KeypointIndex','Parameter','ParameterIndex'}));

Tout = table();

for i = 1:height(groups)

    idx = Terrors.Joint == groups.Joint(i) & ...
          Terrors.Keypoint == groups.Keypoint(i) & ...
          Terrors.Parameter == groups.Parameter(i);

    squaredErrors = Terrors.SquaredError(idx);

    rmse = sqrt(mean(squaredErrors, 'omitnan'));
    n = sum(idx);

    temp = groups(i,:);
    temp.N = n;
    temp.RMSE = rmse;

    Tout = [Tout; temp];

end

end

function addEffectMarkers(Test, Predictors, predictorIndex)
%ADDEFFECTMARKERS Adds paper-style significance/effect-size markers.
%
% Marker logic:
%   *   significant angular effect between 2° and 5°
%   **  significant angular effect greater than 5°
%   x   significant timing effect greater than 3% gait cycle
%
% Statistical significance:
%   Predictors(kp,param,predictorIndex).significance < 0.01
%
% Parameters:
%   param 1 = timing (% gait cycle)
%   param 2 = angle (deg)

pThreshold = 0.01;
angleSmall = 2;     % degrees
angleLarge = 5;     % degrees
timingThr  = 3;     % % gait cycle

nVals = numel(Test);
nKeypoints = size(Test(1).DP,1);

for kp = 1:nKeypoints

    timingValues = nan(1,nVals);
    angleValues  = nan(1,nVals);

    for a = 1:nVals
        timingValues(a) = Test(a).DP(kp,1);
        angleValues(a)  = Test(a).DP(kp,2);
    end

    timingAmp = max(timingValues) - min(timingValues);
    angleAmp  = max(angleValues) - min(angleValues);

    x0 = median(timingValues,'omitnan');
    y0 = median(angleValues,'omitnan');

    % -----------------------------
    % Timing effect marker
    % -----------------------------
    timingSig = false;

    if size(Predictors,2) >= 1 && size(Predictors,3) >= predictorIndex
        if isfield(Predictors(kp,1,predictorIndex),'significance')
            pTiming = Predictors(kp,1,predictorIndex).significance;
            if ~isempty(pTiming) && ~isnan(pTiming) && pTiming < pThreshold
                timingSig = true;
            end
        end
    end

    if timingSig && timingAmp > timingThr
        text(x0, y0, 'x', ...
            'FontSize', 9, ...
            'FontWeight', 'bold', ...
            'Color', 'black', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle');
    end

    % -----------------------------
    % Angular effect marker
    % -----------------------------
    angleSig = false;

    if size(Predictors,2) >= 2 && size(Predictors,3) >= predictorIndex
        if isfield(Predictors(kp,2,predictorIndex),'significance')
            pAngle = Predictors(kp,2,predictorIndex).significance;
            if ~isempty(pAngle) && ~isnan(pAngle) && pAngle < pThreshold
                angleSig = true;
            end
        end
    end

    if angleSig && angleAmp > angleLarge
        text(x0, y0 + 2, '**', ...
            'FontSize', 9, ...
            'FontWeight', 'bold', ...
            'Color', 'black', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    elseif angleSig && angleAmp >= angleSmall && angleAmp <= angleLarge
        text(x0, y0 + 2, '*', ...
            'FontSize', 9, ...
            'FontWeight', 'bold', ...
            'Color', 'black', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    end

end

end


