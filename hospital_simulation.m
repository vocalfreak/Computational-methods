% =========================================================
% Hospital Emergency Department Queuing Simulation
% CAM6134-T2610 Group Assignment
% =========================================================

function hospital_simulation()

clc;

% ----------------------------------------------------------
% SETTINGS
% ----------------------------------------------------------

simulation_time = 480;        % minutes (8-hour shift)
lambda          = 0.083;      % arrival rate  (patients per minute)
mu              = 0.05;       % service rate  (patients per minute per doctor)
num_doctors     = 2;        % number of doctors
queue_mode      = 'priority'; % 'fifo' or 'priority'

% ----------------------------------------------------------
% INITIALISE DOCTORS  Aisyah
% ----------------------------------------------------------

for d = 1:num_doctors
  doctor(d).status    = 0;   % 0 = idle, 1 = busy
  doctor(d).busy_time = 0;   % total minutes this doctor was treating patients
end

% ----------------------------------------------------------
% INITIALISE PATIENTS & QUEUE
% ----------------------------------------------------------

patients      = struct([]);  % stores each patient's record
patient_count = 0;
queue         = [];          % list of patient IDs currently waiting

% ----------------------------------------------------------
% INITIALISE FUTURE EVENT LIST  [P1 - Syahirah]
% Each event has: time, type (1=arrival / 2=departure),
%                 patientID, doctorID
% ----------------------------------------------------------

future_event = struct([]);

first_arrival.time      = generate_interarrival_time(lambda);
first_arrival.type      = 1;
first_arrival.patientID = 0;
first_arrival.doctorID  = 0;
future_event(1)         = first_arrival;

% ----------------------------------------------------------
% COUNTERS
% ----------------------------------------------------------

served_patients = 0;
clock           = 0;
queue_area      = 0;   % used to calculate average queue length
last_event_time = 0;   % tracks when we last updated queue_area
queue_log       = [];  % records [time, queue_length] at each event

% ==========================================================
% MAIN EVENT LOOP  Syahirah
% ==========================================================

while ~isempty(future_event)

  % Find the event with the smallest (earliest) time
  event_times       = [future_event.time];
  [min_time, idx]   = min(event_times);
  current_event     = future_event(idx);
  future_event(idx) = [];   % remove it from the list

  clock = current_event.time;

  % --- Update time-weighted queue area [P4 - Adriana] ---
  % We accumulate (queue length * time elapsed) before moving the clock forward.
  % This lets us calculate average queue length at the end.
  effective_time = min(clock, simulation_time);
  dt = effective_time - last_event_time;
  if dt > 0
    queue_area      = queue_area + (length(queue) * dt);
    last_event_time = effective_time;
  end

  if clock > simulation_time
    break;
  end


  if current_event.type == 1

    patient_count = patient_count + 1;
    pid           = patient_count;

    patients(pid).arrival_time  = clock;
    patients(pid).priority      = assign_priority();  % [P2 - Alex]
    patients(pid).service_start = -1;  % -1 means not yet served
    patients(pid).service_end   = -1;

    % Schedule the next patient arrival  [P2 - Alex]
    next_arrival = clock + generate_interarrival_time(lambda);
    if next_arrival <= simulation_time
      e.time      = next_arrival;
      e.type      = 1;
      e.patientID = 0;
      e.doctorID  = 0;
      future_event(end + 1) = e;
    end

    % Check if any doctor is free  [P3 - Aisyah]
    free_doctor = 0;
    for d = 1:num_doctors
      if doctor(d).status == 0
        free_doctor = d;
        break;
      end
    end

    if free_doctor ~= 0
      % A doctor is available — serve the patient immediately
      service_time = generate_service_time(mu);  % [P2 - Alex]

      doctor(free_doctor).status    = 1;
      doctor(free_doctor).busy_time = doctor(free_doctor).busy_time + service_time;

      patients(pid).service_start = clock;

      dep.time      = clock + service_time;
      dep.type      = 2;
      dep.patientID = pid;
      dep.doctorID  = free_doctor;
      future_event(end + 1) = dep;

    else
      % All doctors busy — patient joins the queue
      queue(end + 1) = pid;
    end

  else

    pid = current_event.patientID;
    did = current_event.doctorID;

    patients(pid).service_end = clock;
    served_patients           = served_patients + 1;

    if isempty(queue)
      % Nobody waiting — doctor goes idle
      doctor(did).status = 0;

    else
      % Someone is waiting — pick the next patient  [P3 - Aisyah]

      if strcmp(queue_mode, 'priority')
        % Scan the whole queue for the highest priority patient.
        % Lower priority number = more urgent (1 = Critical).
        % If two patients share the same priority, pick the one who arrived first.
        best_index   = 1;
        best_patient = queue(1);

        for k = 2:length(queue)
          candidate = queue(k);

          if patients(candidate).priority < patients(best_patient).priority
            % Found someone more urgent
            best_patient = candidate;
            best_index   = k;

          elseif patients(candidate).priority == patients(best_patient).priority
            % Same urgency — prefer the one who has waited longer
            if patients(candidate).arrival_time < patients(best_patient).arrival_time
              best_patient = candidate;
              best_index   = k;
            end
          end
        end

      else
        % FIFO — just take whoever is at the front
        best_index   = 1;
        best_patient = queue(1);
      end

      queue(best_index) = [];   % remove chosen patient from queue

      service_time = generate_service_time(mu);  % [P2 - Alex]
      patients(best_patient).service_start = clock;

      doctor(did).busy_time = doctor(did).busy_time + service_time;

      dep.time      = clock + service_time;
      dep.type      = 2;
      dep.patientID = best_patient;
      dep.doctorID  = did;
      future_event(end + 1) = dep;

    end

  end   % end event type check

  queue_log(end + 1, :) = [clock, length(queue)];

end   % end main event loop

% Final queue area top-up (covers remaining time after last event)
if last_event_time < simulation_time
  queue_area = queue_area + (length(queue) * (simulation_time - last_event_time));
end

% ==========================================================
% METRICS  Adrianna
% ==========================================================

% Collect wait times (time from arrival to service start)
waits = [];
for i = 1:patient_count
  if patients(i).service_start >= 0
    wait = patients(i).service_start - patients(i).arrival_time;
    waits(end + 1) = wait;
  end
end

if ~isempty(waits)
  avg_waiting_time = mean(waits);
else
  avg_waiting_time = 0;
end

% Average queue length = total queue area / total simulation time
avg_queue_length = queue_area / simulation_time;

total_busy_time = 0;

fprintf('\n--- Doctor Utilization ---\n');
for d = 1:num_doctors
  util            = (doctor(d).busy_time / simulation_time) * 100;
  total_busy_time = total_busy_time + doctor(d).busy_time;
  fprintf('Doctor %d: Busy Time = %.2f min, Utilization = %.2f%%\n', d, doctor(d).busy_time, util);
end

overall_util = (total_busy_time / (num_doctors * simulation_time)) * 100;

fprintf('\n--- Performance Metrics ---\n');
fprintf('Simulation Time        : %d minutes\n',    simulation_time);
fprintf('Number of Doctors      : %d\n',             num_doctors);
fprintf('Queue Mode             : %s\n',             queue_mode);
fprintf('Total Patients Arrived : %d\n',             patient_count);
fprintf('Total Patients Served  : %d\n',             served_patients);
fprintf('Average Waiting Time   : %.4f minutes\n',  avg_waiting_time);
fprintf('Average Queue Length   : %.4f patients\n', avg_queue_length);
fprintf('Overall Utilization    : %.2f%%\n',         overall_util);

if ~isempty(queue_log)
  fprintf('Maximum Queue Length   : %d patients\n', max(queue_log(:,2)));
end

end   % end function hospital_simulation


% ==========================================================
% FUNCTIONS GENERATORS  CHIAM JUIN HOONG
% ==========================================================

function t = generate_interarrival_time(lambda)
  % Generates time until next patient arrives
  % Formula: X = -(1/lambda) * ln(1 - R),  R ~ Uniform(0,1)
  R = rand();
  t = -(1 / lambda) * log(1 - R);
end

function t = generate_service_time(mu)
  % Generates how long a doctor takes to treat one patient
  % Formula: X = -(1/mu) * ln(1 - R),  R ~ Uniform(0,1)
  R = rand();
  t = -(1 / mu) * log(1 - R);
end

function priority = assign_priority()
  % Assigns a priority level based on patient condition
  % 1 = Critical (10%)  |  2 = Urgent (30%)  |  3 = Normal (60%)
  R = rand();
  if R < 0.10
    priority = 1;
  elseif R < 0.40
    priority = 2;
  else
    priority = 3;
  end
end
