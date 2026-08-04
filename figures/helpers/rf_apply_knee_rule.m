function [Yout,reversed,score] = rf_apply_knee_rule(Yin,ruleName)
%RF_APPLY_KNEE_RULE Apply the documented dataset-specific knee sign rule.
% Rule logic: initially multiply by -1; if the rule score is negative,
% multiply by -1 again. reversed is relative to the cleaned input.

Yin = double(Yin);
if size(Yin,1) ~= 101
    error('Knee waveform matrix must have 101 rows.');
end

ruleName = lower(strrep(string(ruleName),'%',''));
Ytrial = -Yin;

switch ruleName
    case {"median55-75","55-75"}
        idx = 56:76;
        score = median(Ytrial(idx,:),1,'omitnan');
    case {"median60-80","60-80"}
        idx = 61:81;
        score = median(Ytrial(idx,:),1,'omitnan');
    case {"median65-85","65-85"}
        idx = 66:86;
        score = median(Ytrial(idx,:),1,'omitnan');
    case {"max50-90","maximum50-90","50-90max"}
        idx = 51:91;
        score = max(Ytrial(idx,:),[],1,'omitnan');
    otherwise
        error('Unknown knee polarity rule: %s',ruleName);
end

restoreInput = score < 0;
Yout = Ytrial;
Yout(:,restoreInput) = -Yout(:,restoreInput);
reversed = (~restoreInput).';
score = score(:);
end
