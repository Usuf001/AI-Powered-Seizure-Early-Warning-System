function results = evaluateEvents(scores, labels, windowStartSec, fileName, opts)
% EVALUATEEVENTS  Event-level evaluation: sensitivity, false alarms/hour, latency.
%   results = evaluateEvents(scores, labels, windowStartSec, fileName)
%   results = evaluateEvents(..., opts)      opts is a struct, all fields optional:
%       threshold    alert threshold                (default cfg.alertThreshold, or 0.5)
%       consecutive  windows in a row needed        (default cfg.alertConsecutiveWindows)
%       windowSec, stepSec                           (defaults from config)
%
% scores          risk score per window (0 to 1)
% labels          0/1 per window (1 = seizure window)
% windowStartSec  start time of each window within its file
% fileName        source file of each window (alerts never span two files)
%
% Rules (README 4.6):
%   - An ALERT fires when the score is >= threshold for N consecutive windows.
%     Its time is the END of the window that completes the run. One alert per run.
%   - A SEIZURE is a block of consecutive labelled windows. Onset = start of the
%     first window, offset = end of the last (accurate to about one window).
%   - A seizure is DETECTED if an alert falls inside it. Latency = first such
%     alert time minus onset.
%   - A FALSE ALARM is an alert outside every seizure.
%   - False alarms per hour = false alarms / seizure-free hours of recording.
%     Only meaningful on FULL recordings (no subsampled windows).

    cfg = config();
    n = numel(scores);
    if nargin < 4 || isempty(fileName), fileName = repmat("recording", n, 1); end
    if nargin < 5 || isempty(opts), opts = struct(); end
    thr     = getOpt(opts, 'threshold',   cfg.alertThreshold);
    if isempty(thr), thr = 0.5; end
    nConsec = getOpt(opts, 'consecutive', cfg.alertConsecutiveWindows);
    winSec  = getOpt(opts, 'windowSec',   cfg.windowSec);
    stepSec = getOpt(opts, 'stepSec',     cfg.stepSec);

    scores = double(scores(:));  labels = double(labels(:));
    t = double(windowStartSec(:));  fileName = string(fileName(:));

    szFile = strings(0,1);  szOnset = zeros(0,1);  szOffset = zeros(0,1);
    szDetected = false(0,1);  szLatency = nan(0,1);
    alFile = strings(0,1);  alTime = zeros(0,1);  alInSeizure = false(0,1);
    totalSec = 0;  seizSec = 0;  pairs = 0;  gapPairs = 0;

    files = unique(fileName, 'stable');
    for i = 1:numel(files)
        idx = find(fileName == files(i));
        [ts, ord] = sort(t(idx));
        idx = idx(ord);
        s = scores(idx);  y = labels(idx);

        blocks = findBlocks(ts, y == 1, stepSec);
        onset  = ts(blocks(:,1));
        offset = ts(blocks(:,2)) + winSec;

        run = 0;  alertT = zeros(0,1);
        for k = 1:numel(s)
            if k > 1 && (ts(k) - ts(k-1)) > stepSec + 1e-6, run = 0; end
            if s(k) >= thr, run = run + 1; else, run = 0; end
            if run == nConsec, alertT(end+1,1) = ts(k) + winSec; end %#ok<AGROW>
        end

        inSz = false(size(alertT));
        for j = 1:numel(onset)
            inThis = alertT >= onset(j) & alertT <= offset(j);
            inSz = inSz | inThis;
            lat = NaN;
            if any(inThis), lat = min(alertT(inThis)) - onset(j); end
            szFile(end+1,1) = files(i);        %#ok<AGROW>
            szOnset(end+1,1) = onset(j);       %#ok<AGROW>
            szOffset(end+1,1) = offset(j);     %#ok<AGROW>
            szDetected(end+1,1) = any(inThis); %#ok<AGROW>
            szLatency(end+1,1) = lat;          %#ok<AGROW>
        end

        alFile = [alFile; repmat(files(i), numel(alertT), 1)]; %#ok<AGROW>
        alTime = [alTime; alertT];                              %#ok<AGROW>
        alInSeizure = [alInSeizure; inSz];                      %#ok<AGROW>

        totalSec = totalSec + (ts(end) - ts(1) + winSec);
        seizSec  = seizSec + sum(offset - onset);
        pairs    = pairs + numel(ts) - 1;
        gapPairs = gapPairs + sum(diff(ts) > stepSec + 1e-6);
    end

    if pairs > 0 && gapPairs / pairs > 0.01
        warning(['Many windows are missing (subsampled data). Sensitivity and ' ...
                 'latency are fine, but false alarms per hour is NOT reliable.']);
    end

    nSz = numel(szDetected);
    hoursFree = (totalSec - seizSec) / 3600;
    results.threshold          = thr;
    results.nSeizures          = nSz;
    results.nDetected          = sum(szDetected);
    results.sensitivity        = sum(szDetected) / nSz;       % NaN if no seizures
    results.falseAlarms        = sum(~alInSeizure);
    results.hoursSeizureFree   = hoursFree;
    results.falseAlarmsPerHour = sum(~alInSeizure) / hoursFree;
    results.medianLatencySec   = median(szLatency, 'omitnan');
    results.seizures = table(szFile, szOnset, szOffset, szDetected, szLatency, ...
        'VariableNames', {'file', 'onsetSec', 'offsetSec', 'detected', 'latencySec'});
    results.alerts = table(alFile, alTime, alInSeizure, ...
        'VariableNames', {'file', 'timeSec', 'insideSeizure'});

    if nargout == 0
        fprintf('Seizures: %d, detected: %d (sensitivity %.2f)\n', ...
                nSz, results.nDetected, results.sensitivity);
        fprintf('False alarms: %d over %.2f seizure-free hours (%.2f per hour)\n', ...
                results.falseAlarms, hoursFree, results.falseAlarmsPerHour);
        fprintf('Median latency: %.1f s\n', results.medianLatencySec);
    end
end

function v = getOpt(opts, name, default)
    if isfield(opts, name) && ~isempty(opts.(name)), v = opts.(name); else, v = default; end
end

function blocks = findBlocks(ts, pos, stepSec)
% Start and end index of each run of consecutive positive windows.
    blocks = zeros(0, 2);
    first = NaN;
    for k = 1:numel(pos)
        contiguous = k > 1 && (ts(k) - ts(k-1)) <= stepSec + 1e-6;
        if pos(k)
            if isnan(first)
                first = k;
            elseif ~contiguous
                blocks(end+1, :) = [first, k-1]; %#ok<AGROW>
                first = k;
            end
        elseif ~isnan(first)
            blocks(end+1, :) = [first, k-1]; %#ok<AGROW>
            first = NaN;
        end
    end
    if ~isnan(first), blocks(end+1, :) = [first, numel(pos)]; end
end
