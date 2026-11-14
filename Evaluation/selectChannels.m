function T2 = selectChannels(T, keepChannels)
% SELECTCHANNELS  Keep only the feature columns of the chosen channels.
%   T2 = selectChannels(T, {'F3-C3','C3-P3','F4-C4','C4-P4'})
% Simulates a recording with fewer channels. Meta columns are always kept.
% Train the model on the SAME reduced table (use trainModel(selectChannels(...))).

    keepTag = erase(string(keepChannels), "-");     % 'F3-C3' -> 'F3C3'
    names = string(T.Properties.VariableNames);
    meta  = ["patientID", "fileName", "windowStartSec", "label"];
    chan  = extractAfter(names, "_");               % channel part of feature names
    keep  = ismember(names, meta) | ismember(chan, keepTag);
    T2 = T(:, keep);
end
