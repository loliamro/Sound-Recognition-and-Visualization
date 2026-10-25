function y = filterNoise(sig, Fs, order)
%FILTERNOISE Bandpass noise filter tuned for a clear, reliable effect.
%
%   y = filterNoise(sig, Fs, order) removes low-frequency rumble/hum
%   (below 150 Hz) and high-frequency hiss/brightness (above 5000 Hz),
%   while leaving the 150-5000 Hz range - where most of a voice's
%   energy and clarity lives - untouched.
%
%   These cutoffs were chosen after testing two extremes:
%     - 300-3400 Hz ("telephone bandwidth") noticeably cleaned the
%       signal, but made the voice sound thin and tinny, like an old
%       phone call.
%     - 80-8000 Hz was too close to the full voice spectrum, so it had
%       almost no audible effect.
%   150-5000 Hz sits between the two: a clearly audible cleanup effect
%   without sounding unnatural.
%
%   "order" controls how sharp the filter's cutoff is (how cleanly it
%   separates the passband from the rejected frequencies). Higher order
%   = sharper, more precise filtering. Always rounded up to odd.
%
%   Built manually as a windowed-sinc FIR bandpass filter, using only
%   conv(), sin(), and cos() - no Signal Processing Toolbox needed.
%
%   this whole file went through like 4 versions before i landed on
%   this one lol. first tried a simple moving average (too weak/muffled
%   the voice), then tried the toolbox functions (broke on machines
%   without the toolbox), so ended up just building it from scratch
%   using the sinc + window method from class

if nargin < 3
    order = 101;   % default if nobody passes an order in, just a reasonable middle value
end
if mod(order,2) == 0
    order = order + 1;   % filter must be an odd length to stay symmetric
                          % (even length messes up the delay/centering math below)
end

fc1 = 150;     % lower cutoff (Hz) - anything below this is just hum/rumble, not voice
fc2 = 5000;    % upper cutoff (Hz) - anything above this is hiss, voice doesn't really go this high

% n is just a list of integers centered on 0, like -50...0...50
% this is so the filter is symmetric, which we need for it to be a real
% (not complex) filter
n = -(order-1)/2 : (order-1)/2;

% Ideal lowpass impulse responses at each cutoff, built from the
% sinc function (written manually so no toolbox is needed)
% basically: sinc function = what a "perfect" lowpass filter looks like
% in the time domain. this comes straight from the fourier transform pair
% between a rectangle (ideal frequency cutoff) and a sinc (time domain)
hLow2 = 2*fc2/Fs * sincManual(2*fc2/Fs*n);
hLow1 = 2*fc1/Fs * sincManual(2*fc1/Fs*n);

% A bandpass filter is just the difference of two lowpass filters
% (lowpass up to fc2) minus (lowpass up to fc1) = only keeps the middle band
hBand = hLow2 - hLow1;

% Apply a Hamming window to smooth the filter's response and reduce
% ringing compared to an unwindowed "ideal" filter
% without this the filter has bad ripples/ringing, learned this the hard
% way when i first tried it without a window and the output sounded weird
w = hammingManual(order)';
hBand = hBand .* w;

% Filter the signal using convolution, then trim back to the
% original signal length
% conv() makes the output longer than the input, so we have to cut off
% the extra padding on both sides to get back to the original length
yFull = conv(sig, hBand);
pad = (order-1)/2;
y = yFull(pad+1 : pad+length(sig));

end


function w = hammingManual(N)
% Manual Hamming window (column vector, length N)
% wrote this myself since hamming() is a toolbox function and i wanted
% this whole project to run on any matlab install, not just ones with
% signal processing toolbox
nn = (0:N-1)';
w = 0.54 - 0.46*cos(2*pi*nn/(N-1));   % this exact formula is just the standard hamming window equation
end


function y = sincManual(x)
% Manual sinc function: sin(pi*x)/(pi*x), with sinc(0) = 1
% again, avoiding the built in sinc() since that also needs a toolbox.
% the 0/0 case has to be handled separately because matlab will just
% give you NaN otherwise, even though the actual limit is 1
y = ones(size(x));
nz = x ~= 0;
y(nz) = sin(pi*x(nz)) ./ (pi*x(nz));
end