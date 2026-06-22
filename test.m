% =========================================================
% Hospital Emergency Department Queuing Simulation
% CAM6134-T2610 Assignment
%
% HOW TO RUN (Octave / FreeMat):
%   hospital_sim
%
% To change scenario, edit the SETTINGS block below.
% =========================================================

clc;
clear;

% ----------------------------------------------------------
% FUNCTIONS  (must be defined before the script body)
% ----------------------------------------------------------

function t = generate_interarrival_time(lambda)
  R = rand();
  t = -(1 / lambda) * log(1 - R);
endfunction

function t = generate_service_time(mu)
  R = rand();
  t = -(1 / mu) * log(1 - R);
endfunction

function priority = assign_priority()
  % Priority 1 = Critical   (~10% of arrivals)
  % Priority 2 = Urgent     (~30% of arrivals)
  % Priority 3 = Non-urgent (~60% of arrivals)
  R = rand();
  if R < 0.10
    priority = 1;
  elseif R < 0.40
    priority = 2;
  else
    priority = 3;
  endif
endfunction

% ----------------------------------------------------------
% SETTINGS  — edit here to change scenarios
% ----------------------------------------------------------

simulation_time = 480;   % minutes (8-hour shift)
num_doctors     = 3;     % number of doctors (servers)
lambda          = 0.30;  % arrival rate  (patients per minute)
mu              = 0.30;  % service rate  (patients per minute per doctor)
queue_mode      = 'priority';  % 'fifo' or 'priority'

% ----------------------------------------------------------
% INITIALISE DOCTORS
% ----------------------------------------------------------

for d = 1:num_doctors
  doctor(d).status    = 0;   % 0 = idle, 1 = busy
  doctor(d).busy_time = 0;   % total minutes spent treating patients
endfor

% ----------------------------------------------------------
% INITIALISE PATIENTS & QUEUE
% ----------------------------------------------------------

patients      = struct([]);  % one entry per patient
patient_count = 0;

queue = [];   % list of waiting patient IDs (in arrival order)

% ----------------------------------------------------------
% INITIALISE FUTURE EVENT LIST (FEL)
% Each event is a struct with fields: time, type, patientID, doctorID
%   type 1 = ARRIVAL
%   type 2 = DEPARTURE
% ----------------------------------------------------------

future_event = struct([]);

first_arrival.time      = generate_interarrival_time(lambda);
first_arrival.type      = 1;
first_arrival.patientID = 0;
first_arrival.doctorID  = 0;

future_event(1) = first_arrival;

% ----------------------------------------------------------
% COUNTERS
% ----------------------------------------------------------

served_patients = 0;
clock           = 0;

% ----------------------------------------------------------
% MAIN EVENT LOOP
% ----------------------------------------------------------

while ~isempty(future_event)

  % --- Find and extract the earliest event ---
  event_times = [future_event.time];
  [~, idx]    = min(event_times);

  current_event      = future_event(idx);
  future_event(idx)  = [];          % remove from FEL

  clock = current_event.time;

  if clock > simulation_time
    break;
  endif

  % ======================================================
  if current_event.type == 1        % ARRIVAL EVENT
  % ======================================================

    patient_count = patient_count + 1;
    pid           = patient_count;

    patients(pid).arrival_time   = clock;
    patients(pid).priority       = assign_priority();
    patients(pid).service_start  = -1;  % -1 means not yet served
    patients(pid).service_end    = -1;

    % Schedule next arrival
    next_arrival_time = clock + generate_interarrival_time(lambda);

    if next_arrival_time <= simulation_time
      e.time      = next_arrival_time;
      e.type      = 1;
      e.patientID = 0;
      e.doctorID  = 0;
      future_event(end + 1) = e;
    endif

    % Find a free doctor
    free_doctor = 0;

    for d = 1:num_doctors
      if doctor(d).status == 0
        free_doctor = d;
        break;
      endif
    endfor

    if free_doctor ~= 0
      % Doctor available — start service immediately
      service_time = generate_service_time(mu);

      doctor(free_doctor).status    = 1;
      doctor(free_doctor).busy_time = doctor(free_doctor).busy_time + service_time;

      patients(pid).service_start = clock;

      dep.time      = clock + service_time;
      dep.type      = 2;
      dep.patientID = pid;
      dep.doctorID  = free_doctor;
      future_event(end + 1) = dep;

    else
      % All doctors busy — join the queue
      queue(end + 1) = pid;

    endif

  % ======================================================
  else                              % DEPARTURE EVENT
  % ======================================================

    pid = current_event.patientID;
    did = current_event.doctorID;

    patients(pid).service_end = clock;
    served_patients           = served_patients + 1;

    if isempty(queue)
      % No one waiting — doctor goes idle
      doctor(did).status = 0;

    else
      % Pick next patient from queue
      if strcmp(queue_mode, 'priority')
        % Highest urgency first (lowest priority number)
        % Tie-break: earliest arrival time (FIFO within same level)
        best_index = 1;
        best_pid   = queue(1);

        for k = 2:length(queue)
          candidate_pid = queue(k);

          if patients(candidate_pid).priority < patients(best_pid).priority
            best_pid   = candidate_pid;
            best_index = k;
          elseif patients(candidate_pid).priority == patients(best_pid).priority
            if patients(candidate_pid).arrival_time < patients(best_pid).arrival_time
              best_pid   = candidate_pid;
              best_index = k;
            endif
          endif
        endfor

      else
        % FIFO — take the front of the queue
        best_index = 1;
        best_pid   = queue(1);
      endif

      queue(best_index) = [];   % remove chosen patient from queue

      % Start service for the chosen patient
      service_time = generate_service_time(mu);

      patients(best_pid).service_start = clock;

      doctor(did).busy_time = doctor(did).busy_time + service_time;

      dep.time      = clock + service_time;
      dep.type      = 2;
      dep.patientID = best_pid;
      dep.doctorID  = did;
      future_event(end + 1) = dep;

    endif

  endif  % event type check

endwhile  % main event loop

% ----------------------------------------------------------
% RESULTS
% ----------------------------------------------------------

% Collect wait times for all patients who were served
waits = [];

for i = 1:patient_count
  if patients(i).service_start >= 0
    waits(end + 1) = patients(i).service_start - patients(i).arrival_time;
  endif
endfor

% Doctor utilisation (fraction of simulation time each doctor was busy)
util = zeros(1, num_doctors);
for d = 1:num_doctors
  util(d) = doctor(d).busy_time / simulation_time;
endfor

avg_wait_time = mean(waits);
avg_util      = mean(util) * 100;  % as a percentage

fprintf('\n=== Simulation Results ===\n');
fprintf('Patients Arrived       : %d\n',    patient_count);
fprintf('Patients Served        : %d\n',    served_patients);
fprintf('Average Wait Time      : %.2f min\n', avg_wait_time);
fprintf('Avg Doctor Utilisation : %.2f%%\n',   avg_util);
fprintf('\nPer-doctor utilisation:\n');
for d = 1:num_doctors
  fprintf('  Doctor %d: %.2f%%\n', d, util(d) * 100);
endfor
