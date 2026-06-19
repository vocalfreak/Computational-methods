function hospital_simulation()

clc;

simulation_time = 480;  %indicating an 8 hours shift
lambda = 0.30;
mu = 0.30;
num_doctors = 4;
queue_mode = 'priority';  %either patients follow FIFO or Priority

for d = 1:num_doctors
  doctor(d).status = 0;
  doctor(d).busy_time = 0;
 end

patients = struct([]);
patient_count = 0;

queue = [];

future_event = struct([]);

first_arrival.time = generate_interarrival_time(lambda);
first_arrival.type = 1;
first_arrival.patientID = 0;
first_arrival.doctorID = 0;

future_event(1) = first_arrival;

served_patients = 0;
total_wait_time = 0;
clock = 0;
queue_log = [];
queue_area = 0;
last_event_time = 0;

while ~isempty(future_event)
  event_time = [future_event.time];
  [~, idx] = min(event_time);


  current_event = future_event(idx);
  future_event(idx) = [];

  clock = current_event.time;

  event_clock = min(clock, simulation_time);
  dt = event_clock - last_event_time;

  if dt > 0
    queue_area = queue_area + (length(queue) * dt);
    last_event_time = event_clock;
  endif

  if clock > simulation_time
    break;
  endif

  if current_event.type == 1
    patient_count = patient_count + 1;
    pid = patient_count;

    patients(pid).arrival_time = clock;
    patients(pid).priority = assign_priority();
    patients(pid).service_start = -1;
    patients(pid).service_end = -1;

    next_arrival = clock + generate_interarrival_time(lambda);

    if next_arrival <= simulation_time
      e.time = next_arrival;
      e.type = 1;
      e.patientID = 0;
      e.doctorID = 0;

      future_event(end + 1) = e;
    endif

    free_doctor = 0;

    for d = 1:num_doctors
      if doctor(d).status == 0
        free_doctor = d;
        break;
      endif
    endfor

    if free_doctor ~= 0
      service_time = generate_service_time(mu);

       doctor(free_doctor).status = 1;

       busy_within_simulation = min(service_time, simulation_time - clock);
       doctor(free_doctor).busy_time = doctor(free_doctor).busy_time + busy_within_simulation;

       patients(pid).service_start = clock;

       dep.time = clock +service_time;
       dep.type = 2;
       dep.patientID = pid;
       dep.doctorID = free_doctor;

       future_event(end + 1) = dep;
    else
       queue(end + 1) = pid;
    endif

  else
    pid = current_event.patientID;
    did = current_event.doctorID;

    patients(pid).service_end = clock;
    served_patients = served_patients + 1;

    if isempty(queue)
      doctor(did).status = 0;
    else
      if strcmp(queue_mode, 'priority')
        best_index = 1;
        best_patient = queue(1);

        for k = 2:length(queue)
          current_patient = queue(k);

          if patients(current_patient).priority < patients(best_patient).priority

            best_patient = current_patient;
            best_index = k;
          elseif patients(current_patient).priority == patients(best_patient).priority
            if patients(current_patient).arrival_time < patients(best_patient).arrival_time
              best_patient = current_patient;
              best_index = k;
            endif
          endif
        endfor
       else
          best_index = 1;
          best_patient = queue(1);
       endif

        queue(best_index) = [];

        service_time = generate_service_time(mu);

        patients(best_patient).service_start = clock;

        busy_within_simulation = min(service_time, simulation_time - clock);
        doctor(did).busy_time = doctor(did).busy_time + busy_within_simulation;

        dep.time = clock + service_time;
        dep.type = 2;
        dep.patientID = best_patient;
        dep.doctorID = did;

        future_event(end + 1) = dep;
    endif
  endif

  queue_log(end+1,:) = [clock, length(queue)];

endwhile

if last_event_time < simulation_time
  queue_area = queue_area + (length(queue) * (simulation_time - last_event_time));
endif

waits = [];

for i = 1:patient_count
  if patients(i).service_start >= 0 && patients(i).service_end >= 0
    waits(end + 1) = patients(i).service_start - patients(i).arrival_time;
  endif
endfor

if ~isempty(waits)
  avg_waiting_time = mean(waits);
else
  avg_waiting_time = 0;
endif

avg_queue_length = queue_area / simulation_time;

total_busy_time = 0;

fprintf('\n--- Doctor Utilization by Doctor ---\n');

for d = 1:num_doctors
  doctor_utilization = (doctor(d).busy_time / simulation_time) * 100;
  total_busy_time = total_busy_time + doctor(d).busy_time;

  fprintf('Doctor %d: Busy Time = %.2f minutes, Utilization = %.2f%%\n', ...
          d, doctor(d).busy_time, doctor_utilization);
endfor

overall_doctor_utilization = (total_busy_time / (num_doctors * simulation_time)) * 100;

fprintf('\n--- Final Performance Metrics ---\n');
fprintf('Simulation Time: %d minutes\n', simulation_time);
fprintf('Number of Doctors: %d\n', num_doctors);
fprintf('Queue Mode: %s\n', queue_mode);
fprintf('Total Patients Arrived: %d patients\n', patient_count);
fprintf('Total Patients Served: %d patients\n', served_patients);
fprintf('Average Waiting Time: %.4f minutes\n', avg_waiting_time);
fprintf('Average Queue Length: %.4f patients\n', avg_queue_length);
fprintf('Overall Doctor Utilization: %.2f%%\n', overall_doctor_utilization);

if ~isempty(queue_log)
  fprintf('Maximum Queue Length: %d patients\n', max(queue_log(:,2)));
endif

endfunction

function t = generate_interarrival_time(lambda)
  R = rand();
  t = -(1 / lambda) * log(1 - R);
endfunction


function t = generate_service_time(mu)
  R = rand();
  t = -(1 / mu) * log(1 - R);
endfunction


function priority = assign_priority()

  R = rand();

  if R < 0.10
    priority = 1;
  elseif R < 0.40
    priority = 2;
  else
    priority = 3;
  endif

endfunction
