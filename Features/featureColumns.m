function cols = featureColumns(T)
% FEATURECOLUMNS  Names of the feature columns in a feature table (everything
% except patientID, fileName, windowStartSec and label).
    meta  = {'patientID', 'fileName', 'windowStartSec', 'label'};
    names = T.Properties.VariableNames;
    cols  = names(~ismember(names, meta));
end
