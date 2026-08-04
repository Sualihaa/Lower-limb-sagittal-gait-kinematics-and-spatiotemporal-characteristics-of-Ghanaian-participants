function T = rf_load_validation_table(cfg)
%RF_LOAD_VALIDATION_TABLE Load long-form leave-one-participant-out results.

candidates = {
    fullfile(cfg.csvDir,'Validation_Long.csv')
    fullfile(cfg.csvDir,'validation_long.csv')
    };

path = '';
for i = 1:numel(candidates)
    if isfile(candidates{i}); path = candidates{i}; break; end
end

if ~isempty(path)
    T = readtable(path,'VariableNamingRule','preserve');
else
    T = table();
    for j = 1:numel(cfg.joints)
        p = fullfile(cfg.csvDir,sprintf('Validation_%s.csv',cfg.joints(j)));
        if ~isfile(p)
            error(['No Validation_Long.csv and missing joint file: %s. ' ...
                'Run MAIN_fitGait_TRACEABLE first.'],p);
        end
        temp = readtable(p,'VariableNamingRule','preserve');
        if ~ismember('Joint',temp.Properties.VariableNames)
            temp.Joint = repmat(cfg.joints(j),height(temp),1);
        end
        T = [T; temp]; %#ok<AGROW>
    end
end

T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);
T = standardiseNames(T);

required = {'Joint','SubjectRemoved','RMSE','R2','VAF','MAX'};
for i = 1:numel(required)
    if ~ismember(required{i},T.Properties.VariableNames)
        error('Validation table lacks required column: %s',required{i});
    end
end

T.Joint = string(T.Joint);
end

function T = standardiseNames(T)
map = {
    'Subject','SubjectRemoved'
    'Participant','SubjectRemoved'
    'RemovedSubject','SubjectRemoved'
    'R_2','R2'
    'Rsquared','R2'
    'Max','MAX'
    'MaximumError','MAX'
    };
for i = 1:size(map,1)
    if ismember(map{i,1},T.Properties.VariableNames) && ...
            ~ismember(map{i,2},T.Properties.VariableNames)
        T.Properties.VariableNames{strcmp(T.Properties.VariableNames,map{i,1})} = map{i,2};
    end
end
end
