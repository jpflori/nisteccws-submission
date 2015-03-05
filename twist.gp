\\ Estime le facteur devant 1/log² p
\\ pour la probabilité d'avoir une courbe à la fois sûre et twis-sûre.
\\ Local factor for the product
locfact(p,l) = {
  if (l == 2, return (2/3));
  if (l == 3, return (3/4));
  if (!(p-1)%l, return (1-(l^2-l+4)/2/(l+1)/(l-1)/(l-2)));
  if (kronecker (p, l) == -1, return (1-2/(l-1)/(l-2)));
  return (1-(l^2-l+4)/(l+1)/(l-1)/(l-2));
}

prob(p, B = 2^16) = {
  local (c); c = 2/3.;
  forprime (l = 3, B, c *= locfact (p, l));
}

plotcvg (p, B, file, S = 10) = {
  local (t, c); t = 0; c = 2/3.;
  unlink (file);
  forprime (l = 3, B,
    c *= locfact (p, l);
    t++; if (!(t % S), write (file, Str (l, "\t", c)));
  );
}

compute(p, file) = {
  plotcvg (p, 2^18, "twist.dat", 16);
  system (Str ("(echo -n ", p, "' ';
  echo \"f(x)=1/(a+b*log(x)); fit f(x) 'twist.dat' via a,b;
  print a,b\" | gnuplot - 2>&1 | tail -2 | head -1) >> ", file));
}

stats(a,b,n,file) = {
  for (i = 1, n,
    compute (nextprime (a + random(b)), file);
  );
}

\\ Calcule la probabilité de non-arrêt anticipé de SEA,
\\ soit la proba que N soit premier à tout ℓ < B.
p early(B,s=10,file) = {
  local (p, c); p = 1.; c = 0;
  forprime (l = 2, B,
    p *= (l-1)/l; c++;
    if (!(c%s), write (file, Str (l, "\t", p)));
 );
}
