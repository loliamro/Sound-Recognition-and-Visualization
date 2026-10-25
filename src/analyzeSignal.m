function results = analyzeSignal(sig, Fs)
%ANALYZESIGNAL Compute all required signal analysis quantities.
%
%   results = analyzeSignal(sig, Fs) takes a recorded (or filtered)
%   audio signal "sig" sampled at "Fs" Hz, and returns a struct
%   containing everything the project asks for:
%
%       results.t         - time vector (seconds)
%       results.sig       - the signal itself (column vector)
%       results.f         - frequency vector (Hz), positive frequencies only
%       results.mag       - Fourier Transform magnitude |X(f)|
%       results.powerSpec - power spectrum
%       results.psd       - power spectral density
%       results.maxFreq   - frequency of the strongest speech component (Hz)
%       results.peakPSD   - peak value of the PSD
%       results.energy    - signal energy
%       results.meanVal   - mean of the signal
%       results.stdVal    - standard deviation of the signal
%       results.varVal    - variance of the signal
%       results.specT     - spectrogram time axis (seconds)
%       results.specF     - spectrogram frequency axis (Hz)
%       results.specData  - spectrogram magnitude (freq bins x time frames)
%
%   This function only computes numbers - it does not plot or touch the
%   GUI, so it can also be called directly from the command window to
%   test the math on any recording, e.g.:
%       [sig,Fs] = audioread('amro_recording.wav');
%       r = analyzeSignal(sig,Fs);
%
%   kept this file completely separate from the GUI on purpose - makes
%   it way easier to test, i literally just ran this on a bunch of my
%   saved wav files from the command line to check the numbers before
%   ever touching the GUI code

sig = sig(:);            % make sure the signal is a column vector
                          % (audioread sometimes gives rows depending on the file, this avoids weird bugs later)
N = length(sig);
t = (0:N-1)'/Fs;          % time axis, just sample number divided by sample rate

% ---- Fourier Transform ----
X = fft(sig);             % this does basically all the heavy lifting, everything below is just processing X
mag = abs(X);                    % magnitude of the FFT - X itself is complex, we only care about size here
f = (0:N-1)*(Fs/N);              % frequency axis (Hz) - each fft bin corresponds to a specific frequency

half = 1:floor(N/2);             % keep only positive frequencies
                                  % fft gives you a mirrored/symmetric result for real signals, so the second
                                  % half is basically the same info repeated, no point plotting it
f = f(half);
mag = mag(half);

% ---- Power spectrum ----
powerSpec = mag.^2 / N;   % power = magnitude squared, dividing by N just keeps the scale sane

% ---- Max frequency component ----
% Ignore everything below 50 Hz: real speech starts around 85 Hz,
% but recordings often have low-frequency rumble/drift near 0 Hz
% that would otherwise dominate.
% (found this out the hard way - first version of this kept saying
% "max frequency = 8Hz" or something dumb like that because of mic noise)
minFreq = 50;
magSearch = mag;
magSearch(f < minFreq) = 0;   % zero out anything below 50Hz so it can't win the max() below
[~, idx] = max(magSearch);
maxFreq = f(idx);

% ---- Power spectral density ----
psd = powerSpec / Fs;   % dividing again by Fs so it doesn't matter how long the recording was
peakPSD = max(psd);

% ---- Energy (sum of squared samples) ----
energy = sum(sig.^2);   % straight from parsevals theorem, sum of squared samples = signal energy

% ---- Statistical features ----
meanVal = mean(sig);
stdVal  = std(sig);
varVal  = var(sig);
% these 3 are just built in matlab functions, nothing fancy going on here

% ---- Spectrogram (how the frequency content changes over time) ----
% The signal is split into short overlapping frames. Each frame gets
% its own FFT, so the result is a 2D map: frequency (rows) vs time
% (columns), with color/intensity showing how strong each frequency
% is at each moment - this is what lets you literally see the
% different syllables of speech as they happen.
frameLen = 512;   % tried a couple different values here, 512 gave the best balance for how long i talk
hop = 128;        % how far the window slides each step - smaller hop = smoother but slower to compute
win = hannLocal(frameLen);   % windowing each little chunk before fft-ing it, same idea as the filter file

numFrames = max(1, floor((N - frameLen)/hop) + 1);
nBins = floor(frameLen/2);
specData = zeros(nBins, numFrames);   % pre-allocating this so the loop below doesn't grow the array every time (slow otherwise)

for i = 0:numFrames-1
    idx2 = i*hop + (1:frameLen);
    idx2 = idx2(idx2 <= N);         % near the end of the signal the frame might run off the edge, this catches that
    frame = zeros(frameLen,1);
    frame(1:length(idx2)) = sig(idx2);   % pad with zeros if the frame got cut short
    Xs = fft(frame .* win);
    specData(:,i+1) = abs(Xs(1:nBins));   % +1 because matlab arrays start at 1, not 0, easy to mess this up
end

specF = (0:nBins-1)' * (Fs/frameLen);
specT = ((0:numFrames-1)*hop + frameLen/2) / Fs;   % using the middle of each frame as its "time", felt more accurate than the start

% ---- Pack everything into one struct to return ----
% just bundling everything up so the GUI file can grab it all in one go
% instead of me having to return like 15 separate variables
results.t         = t;
results.sig       = sig;
results.f         = f;
results.mag       = mag;
results.powerSpec = powerSpec;
results.psd       = psd;
results.maxFreq   = maxFreq;
results.peakPSD   = peakPSD;
results.energy    = energy;
results.meanVal   = meanVal;
results.stdVal    = stdVal;
results.varVal    = varVal;
results.specT     = specT;
results.specF     = specF;
results.specData  = specData;

end


function w = hannLocal(N)
    % Manual Hann window (column vector, length N)
    % same reasoning as filterNoise.m - avoiding the built in hann()
    % function since it needs signal processing toolbox
    n = (0:N-1)';
    w = 0.5*(1 - cos(2*pi*n/(N-1)));
end