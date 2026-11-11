function checkPatient(patientID)
% CHECKPATIENT  Sanity-check one patient's raw files and processed .mat file.
%   checkPatient('chb14')
% Prints file counts, window counts, the seizure share, a line-length comparison
% (seizure windows should be clearly higher) and seizure windows per file.
% Reads the big array in chunks, so it is safe for the large test patients.

    cfg = config();
    patientID = char(patientID);

    rawDir = fullfile(cfg.rawDir, patientID);
    nEdf = numel(dir(fullfile(rawDir, '*.edf')));
    hasSummary = isfile(fullfile(rawDir, [patientID '-summary.txt']));
    fprintf('\n%s raw: %d EDF files, summary file present: %d\n', patientID, nEdf, hasSummary);

    m = matfile(fullfile(cfg.processedDir, [patientID '.mat']));
    sz = size(m, 'windows');
    labels = m.labels;
    fileName = m.fileName;
    fprintf('windows: %d x %d x %d\n', sz(1), sz(2), sz(3));
    fprintf('seizure windows: %d (%.1f%% of all windows)\n', sum(labels), 100 * mean(labels));

    ll = zeros(sz(1), 1);
    chunk = 2000;
    for i1 = 1:chunk:sz(1)
        i2 = min(i1 + chunk - 1, sz(1));
        w = m.windows(i1:i2, :, :);
        ll(i1:i2) = mean(sum(abs(diff(w, 1, 3)), 3), 2);
    end
    llSz = mean(ll(labels == 1));
    llNo = mean(ll(labels == 0));
    fprintf('mean line length: seizure %.0f, seizure-free %.0f (ratio %.1f)\n', ...
            llSz, llNo, llSz / llNo);

    [g, f] = findgroups(fileName);
    counts = splitapply(@sum, labels, g);
    disp(table(f, counts, 'VariableNames', {'file', 'seizureWindows'}));
end
