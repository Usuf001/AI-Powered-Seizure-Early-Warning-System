function T = buildFeatureTable(patientID)
% BUILDFEATURETABLE  Make and save the feature table for one processed patient.
%   T = buildFeatureTable('chb05')
%
% Reads Data/processed/<patientID>.mat in chunks (safe for the large test
% patients), computes features, and saves Data/features/<patientID>.mat
% containing the table T. Columns: patientID, fileName, windowStartSec, label,
% then the 126 feature columns.

    cfg = config();
    patientID = char(patientID);
    m = matfile(fullfile(cfg.processedDir, [patientID '.mat']));
    sz = size(m, 'windows');

    chunk = 2000;
    parts = {};
    for i1 = 1:chunk:sz(1)
        i2 = min(i1 + chunk - 1, sz(1));
        parts{end+1} = extractFeatures(m.windows(i1:i2, :, :), cfg.fs, cfg.channelNames); %#ok<AGROW>
        fprintf('  %s: features for windows %d-%d of %d\n', patientID, i1, i2, sz(1));
    end
    F = vertcat(parts{:});

    meta = table(repmat(string(patientID), sz(1), 1), m.fileName, ...
                 m.windowStartSec, m.labels, ...
                 'VariableNames', {'patientID', 'fileName', 'windowStartSec', 'label'});
    T = [meta F]; %#ok<NASGU>

    outDir = fullfile(cfg.dataRoot, 'features');
    if ~isfolder(outDir), mkdir(outDir); end
    save(fullfile(outDir, [patientID '.mat']), 'T');
    fprintf('Saved %s (%d rows, %d columns)\n', ...
            fullfile(outDir, [patientID '.mat']), sz(1), width(T));
    T = [meta F];
end
