function T = extractFeatures(windows, fs, channelNames)
% EXTRACTFEATURES  Turn EEG windows into one row of features per window.
%   T = extractFeatures(windows, fs, channelNames)
%
%   windows       windows x channels x samples (the array from the processed .mat)
%   fs            sampling rate in Hz (default: cfg.fs)
%   channelNames  cell array of channel names (default: cfg.channelNames)
%
% Features per channel (7 x 18 channels = 126 columns):
%   delta, theta, alpha, beta, gamma  RELATIVE band power (band power divided by
%                                     total 0.5-40 Hz power), so patients with
%                                     different signal amplitudes are comparable
%   lineLength                        log10 of the summed absolute sample-to-sample
%                                     change (how jagged the signal is)
%   specEntropy                       normalised spectral entropy (0 to 1; high
%                                     means a flat, noise-like spectrum)
% Column names look like  delta_FP1F7  or  lineLength_CZPZ.

    cfg = config();
    if nargin < 2 || isempty(fs), fs = cfg.fs; end
    if nargin < 3 || isempty(channelNames), channelNames = cfg.channelNames; end

    [nWin, nCh, nSamp] = size(windows);
    bandNames = fieldnames(cfg.bands);
    nB = numel(bandNames);
    nF = nB + 2;

    f = (0:nSamp-1) * fs / nSamp;
    useBin = f >= cfg.bandpassHz(1) & f <= cfg.bandpassHz(2);
    hw = reshape(hann(nSamp, 'periodic'), 1, 1, nSamp);

    feats = zeros(nWin, nCh, nF);
    chunk = 500;
    for i1 = 1:chunk:nWin
        i2 = min(i1 + chunk - 1, nWin);
        w = double(windows(i1:i2, :, :));

        ll = log10(sum(abs(diff(w, 1, 3)), 3) + eps);      % chunk x nCh

        w = (w - mean(w, 3)) .* hw;
        P = abs(fft(w, [], 3)) .^ 2;                       % chunk x nCh x nSamp
        totalP = sum(P(:, :, useBin), 3);                  % chunk x nCh
        for b = 1:nB
            band = cfg.bands.(bandNames{b});
            mask = f >= band(1) & f < band(2);
            feats(i1:i2, :, b) = sum(P(:, :, mask), 3) ./ totalP;
        end
        Pn = P(:, :, useBin) ./ totalP;
        H = -sum(Pn .* log2(Pn + eps), 3) / log2(nnz(useBin));

        feats(i1:i2, :, nB + 1) = ll;
        feats(i1:i2, :, nB + 2) = H;
    end

    featNames = [string(bandNames)', "lineLength", "specEntropy"];
    names = strings(1, nCh * nF);
    col = 0;
    for k = 1:nF
        for c = 1:nCh
            col = col + 1;
            names(col) = featNames(k) + "_" + erase(string(channelNames{c}), "-");
        end
    end
    T = array2table(reshape(feats, nWin, nCh * nF), 'VariableNames', cellstr(names));
end
