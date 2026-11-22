function [windows, startSec] = readEdfWindows(edfPath, cfg)
% READEDFWINDOWS  Read one EDF file into filtered 5-second windows. No labels needed.
%   [windows, startSec] = readEdfWindows('C:\path\recording.edf')
%
% Keeps the 18 channels the model was trained on, resamples to 256 Hz if the file
% uses another rate, band-pass filters 0.5-40 Hz, and cuts 5 s windows every 2.5 s
% (same settings as buildPatientData, taken from config.m).
%   windows   windows x 18 x 1280 (single)
%   startSec  start time of each window within the file, in seconds

    if nargin < 2 || isempty(cfg), cfg = config(); end
    edfPath = char(edfPath);
    hdr = edfinfo(edfPath);
    idx = matchChannels(hdr.SignalLabels, cfg.channelNames);
    if isempty(idx)
        miss = missingChannels(hdr.SignalLabels, cfg.channelNames);
        error('readEdfWindows:channels', ...
            ['%s does not contain all the channels the model needs.\n' ...
             'Missing: %s\nThe final model uses the 18 standard bipolar channels.'], ...
            edfPath, strjoin(miss, ', '));
    end

    tt = edfread(edfPath);
    vn = tt.Properties.VariableNames;
    nCh = numel(idx);
    cols = cell(1, nCh);
    for c = 1:nCh
        cols{c} = vertcat(tt.(vn{idx(c)}){:});
    end
    nSamp = min(cellfun(@numel, cols));
    x = zeros(nSamp, nCh);
    for c = 1:nCh
        x(:, c) = cols{c}(1:nSamp);
    end
    clear tt cols

    fsFile = nSamp / (hdr.NumDataRecords * seconds(hdr.DataRecordDuration));
    if abs(fsFile - cfg.fs) > 0.5
        [pp, qq] = rat(cfg.fs / fsFile);
        x = resample(x, pp, qq);
        nSamp = size(x, 1);
    end

    [z, p, kk] = butter(4, cfg.bandpassHz / (cfg.fs / 2), 'bandpass');
    [sos, g] = zp2sos(z, p, kk);
    x = filtfilt(sos, g, x);

    win = cfg.windowSamples;
    step = round(cfg.stepSec * cfg.fs);
    nWin = floor((nSamp - win) / step) + 1;
    if nWin < 1
        error('readEdfWindows:short', '%s is shorter than one %d-second window.', ...
              edfPath, cfg.windowSec);
    end
    windows = zeros(nWin, nCh, win, 'single');
    for w = 1:nWin
        s = (w - 1) * step + 1;
        windows(w, :, :) = single(x(s:s + win - 1, :)');
    end
    startSec = (0:nWin - 1)' * step / cfg.fs;
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

function miss = missingChannels(signalLabels, wanted)
    signalLabels = string(signalLabels);
    miss = {};
    for c = 1:numel(wanted)
        if ~any(signalLabels == wanted{c}) && ~any(startsWith(signalLabels, string(wanted{c}) + "-"))
            miss{end+1} = wanted{c}; %#ok<AGROW>
        end
    end
end
