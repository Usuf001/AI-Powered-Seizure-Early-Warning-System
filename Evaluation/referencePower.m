function ref = referencePower(patientID)
% REFERENCEPOWER  Typical signal power of each channel for one patient.
%   ref = referencePower('chb14')      1 x 18, the median over windows
% Used by addNoise so that noise is set relative to the patient's usual signal
% level, not window by window. Reads only some of the windows (fast).

    cfg = config();
    m = matfile(fullfile(cfg.processedDir, [char(patientID) '.mat']));
    sz = size(m, 'windows');
    chunk = 500;
    starts = 1:chunk:sz(1);
    starts = starts(1:3:end);                          % every third chunk
    med = zeros(numel(starts), sz(2));
    for i = 1:numel(starts)
        i2 = min(starts(i) + chunk - 1, sz(1));
        w = double(m.windows(starts(i):i2, :, :));
        med(i, :) = median(mean(w .^ 2, 3), 1);
    end
    ref = median(med, 1);
end
