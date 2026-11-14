function T = buildNoisyFeatures(patientID, snrDb)
% BUILDNOISYFEATURES  Feature table for a patient after adding noise to the windows.
%   T = buildNoisyFeatures('chb14', 10)
% Reads Data/processed/<patientID>.mat in chunks (safe for big patients), adds
% noise at snrDb with addNoise, then extracts features. Nothing is saved.

    cfg = config();
    rng(42);
    patientID = char(patientID);
    m = matfile(fullfile(cfg.processedDir, [patientID '.mat']));
    sz = size(m, 'windows');

    chunk = 2000;
    parts = {};
    for i1 = 1:chunk:sz(1)
        i2 = min(i1 + chunk - 1, sz(1));
        w = addNoise(m.windows(i1:i2, :, :), snrDb);
        parts{end+1} = extractFeatures(w, cfg.fs, cfg.channelNames); %#ok<AGROW>
    end
    F = vertcat(parts{:});
    meta = table(repmat(string(patientID), sz(1), 1), m.fileName, ...
                 m.windowStartSec, m.labels, ...
                 'VariableNames', {'patientID', 'fileName', 'windowStartSec', 'label'});
    T = [meta F];
end
