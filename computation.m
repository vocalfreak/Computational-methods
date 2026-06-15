function t = generate_interarrival_time(lambda)
  R = rand();
  t = -(1 / lambda) * log(1 - R);
end

function t = generate_service_time(mu)
  R = rand();
  t = -(1 / mu) * log(1 - R);
end

function priority = assign_priority()

  R = rand();

  if R < 0.10
    priority = 1;
  elseif R < 0.40
    priority = 2;
  else
    priority = 3;
  end

end
