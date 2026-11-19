function buildPatientData(patientID, cfg, keepAll)
% BUILDPATIENTDATA  Turn one patient's raw CHB-MIT files into a processed .mat file.
%   buildPatientData('chb05')
%   buildPatientData('chb05', config(), true)   keep EVERY window and save as
%                                                chb05_full.mat (training patients only;
%                                                used to measure false alarms per hour)
%
% Steps: read each downloaded EDF file, keep the agreed 18 channels, band-pass
% filter, cut into windows, label each window from the summary file, and save
% Data/processed/<patientID>.mat (see README section 4.3).
%
% Training patients keep every seizure window and a subsample of seizure-free
% windows (cfg.negativePerPositive per seizure window). Test patients keep
% every window, so false alarms per hour is meaningful.

    if nargin < 2 || isempty(cfg), cfg = config(); end
    if nargin < 3, keepAll = false; end
    rng(42);
    patientID = char(patientID);
    isTest = ismember(patientID, cfg.testPatients) || keepAll;
    outName = patientID;
    if keepAll && ~ismember(patientID, cfg.testPatients), outName = [patientID '_full']; end

    rawPatientDir = fullfile(cfg.rawDir, patientID);
    summaryPath   = fullfile(rawPatientDir, [patientID '-summary.txt']);
    assert(isfile(summaryPath), 'Missing summary file: %s', summaryPath);
    seizures = parseSummary(summaryPath);

    edfs = dir(fullfile(rawPatientDir, '*.edf'));
    assert(~isempty(edfs), 'No EDF files found in %s', rawPatientDir);
    names = sort(string({edfs.name}));

    win  = cfg.windowSamples;
    step = round(cfg.stepSec * cfg.fs);
    nCh  = numel(cfg.channelNames);

    % ---- Pass 1: header only. Work out windows, labels and which to keep ----
    plan = struct('name', {}, 'idx', {}, 'starts', {}, 'labels', {}, 'keep', {});
    skipped = strings(0, 1);
    for i = 1:numel(names)
        f = fullfile(rawPatientDir, names(i));
        info = edfinfo(f);
        idx = matchChannels(info.SignalLabels, cfg.channelNames);
        if isempty(idx)
            warning('%s is missing some of the 18 channels. Skipped.', names(i));
            skipped(end+1, 1) = names(i); %#ok<AGROW>
            continue
        end
        nSamp = round(info.NumDataRecords * seconds(info.DataRecordDuration) * cfg.fs);
        nWin  = floor((nSamp - win) / step) + 1;
        if nWin < 1, continue, end
        starts = (0:nWin-1)' * step;                 % 0-based sample index
        startSec = starts / cfg.fs;
        iv = zeros(0, 2);
        if isKey(seizures, char(names(i))), iv = seizures(char(names(i))); end
        labels = windowLabels(startSec, iv, cfg.windowSec, cfg.labelOverlapMin);
        k = numel(plan) + 1;
        plan(k).name = names(i); plan(k).idx = idx;
        plan(k).starts = starts; plan(k).labels = labels; plan(k).keep = [];
    end
    assert(~isempty(plan), 'No usable files for %s.', patientID);

    allLabels = vertcat(plan.labels);
    nPos = sum(allLabels == 1);
    nNeg = sum(allLabels == 0);
    if nPos == 0
        warning('%s: no seizure windows found. Check the summary file.', patientID);
    end
    if isTest
        q = 1;
    else
        q = min(1, cfg.negativePerPositive * max(nPos, 1) / max(nNeg, 1));
    end
    for k = 1:numel(plan)
        posIdx = find(plan(k).labels == 1);
        negIdx = find(plan(k).labels == 0);
        nKeepNeg = round(q * numel(negIdx));
        negIdx = negIdx(randperm(numel(negIdx), nKeepNeg));
        plan(k).keep = sort([posIdx; negIdx]);
    end
    nKept = sum(arrayfun(@(p) numel(p.keep), plan));
    fprintf('%s: %d windows kept (%d seizure windows, %d files)\n', ...
            patientID, nKept, nPos, numel(plan));

    % ---- Pass 2: read, filter, window ----
    windows        = zeros(nKept, nCh, win, 'single');
    labelsOut      = zeros(nKept, 1);
    windowStartSec = zeros(nKept, 1);
    fileName       = strings(nKept, 1);

    [z, p, kgain] = butter(4, cfg.bandpassHz / (cfg.fs / 2), 'bandpass');
    [sos, g] = zp2sos(z, p, kgain);

    row = 0;
    for k = 1:numel(plan)
        if isempty(plan(k).keep), continue, end
        f  = fullfile(rawPatientDir, plan(k).name);
        tt = edfread(f);
        vn = tt.Properties.VariableNames;
        nSamp = numel(vertcat(tt.(vn{plan(k).idx(1)}){:}));
        x = zeros(nSamp, nCh);
        for c = 1:nCh
            x(:, c) = vertcat(tt.(vn{plan(k).idx(c)}){:});
        end
        x = filtfilt(sos, g, x);
        for w = plan(k).keep'
            s = plan(k).starts(w) + 1;               % 1-based
            row = row + 1;
            windows(row, :, :)  = single(x(s:s+win-1, :)');
            labelsOut(row)      = plan(k).labels(w);
            windowStartSec(row) = plan(k).starts(w) / cfg.fs;
            fileName(row)       = plan(k).name;
        end
        fprintf('  done %s\n', plan(k).name);
    end

    % ---- Save ----
    if ~isfolder(cfg.processedDir), mkdir(cfg.processedDir); end
    labels = labelsOut; %#ok<NASGU>
    fs = cfg.fs; %#ok<NASGU>
    channelNames = cfg.channelNames; %#ok<NASGU>
    skippedFiles = skipped; %#ok<NASGU>
    outPath = fullfile(cfg.processedDir, [outName '.mat']);
    save(outPath, 'windows', 'labels', 'windowStartSec', 'fileName', ...
         'patientID', 'fs', 'channelNames', 'skippedFiles', '-v7.3');
    fprintf('Saved %s\n', outPath);
end

% ------------------------------------------------------------------------
function seizures = parseSummary(path)
% Returns a map: EDF file name -> N x 2 matrix of [startSec endSec].
    seizures = containers.Map('KeyType', 'char', 'ValueType', 'any');
    lines = splitlines(fileread(path));
    cur = '';  pendingStart = NaN;
    for i = 1:numel(lines)
        ln = strtrim(lines{i});
        tok = regexp(ln, '^File Name:\s*(\S+)', 'tokens', 'once');
        if ~isempty(tok)
            cur = tok{1};  seizures(cur) = zeros(0, 2);  continue
        end
        if isempty(cur), continue, end
        ts = regexp(ln, '^Seizure\s*\d*\s*Start Time:\s*(\d+)\s*seconds', 'tokens', 'once');
        if ~isempty(ts), pendingStart = str2double(ts{1}); continue, end
        te = regexp(ln, '^Seizure\s*\d*\s*End Time:\s*(\d+)\s*seconds', 'tokens', 'once');
        if ~isempty(te)
            iv = seizures(cur);
            iv(end+1, :) = [pendingStart, str2double(te{1})]; %#ok<AGROW>
            seizures(cur) = iv;
        end
    end
end

function labels = windowLabels(startSec, iv, winSec, minFrac)
% 1 if at least minFrac of the window overlaps any seizure interval.
    overlap = zeros(size(startSec));
    for j = 1:size(iv, 1)
        overlap = overlap + max(0, min(iv(j,2), startSec + winSec) - max(iv(j,1), startSec));
    end
    labels = double(overlap / winSec >= minFrac);
end

function idx = matchChannels(signalLabels, wanted)
% Position of each wanted channel in the file, or [] if any is missing.
    signalLabels = string(signalLabels);
    idx = zeros(1, numel(wanted));
    for c = 1:numel(wanted)
        k = find(signalLabels == wanted{c}, 1);
        if isempty(k)   % some files label a duplicated channel with a suffix
            k = find(startsWith(signalLabels, string(wanted{c}) + "-"), 1);
        end
        if isempty(k), idx = []; return, end
        idx(c) = k;
    end
end
