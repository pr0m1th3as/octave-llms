# Large Language Models for GNU Octave

**Not a package yet!** Just a playground for querying Large Language Models through our familiar Octave language.
The included header-only libraries originate from James Montgomery's [@jmont-dev](https://github.com/jmont-dev) repository found [here](https://github.com/jmont-dev/ollama-hpp).

Download into a convenient folder and compile the `__ollama__` function with
```
mkoctfile __ollama__.cc
```

Make sure you have an ollama server instance running either locally
```
>> A = ollama
A =

  ollama interface connected at: http://localhost:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)

     There are 4 available models on this server.
```
or remotelly
```
>> A = ollama ('http://192.168.5.18:11434')
A =

  ollama interface connected at: http://192.168.5.18:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)

     There are 4 available models on this server.
```
See available models with
```
>> A.availableModels
ans =
{
  [1,1] = deepseek-r1:7b
  [1,2] = llama2:latest
  [1,3] = new_codellama:latest
  [1,4] = codellama:latest
}
```
Load one (either by name or by linear index)
```
>> A.activeModel = 2
A =

  ollama interface connected at: http://192.168.5.18:11434

              activeModel: 'deepseek-coder:6.7b'
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)

     There are 4 available models on this server.
```
And start inference
```
>> txt = generate(A, "Write a GNU Octave function to calculate the center of a circle from 3 points along its perimeter.")
txt = Sure, here is an example of how you can do this in GNU Octave. This function takes three points (x1, y1), (x2, y2)
and (x3, y3) as input parameters and returns the center of the circle as (xc, yc).

'''octave
function [xc, yc] = find_circle(x1,y1, x2,y2, x3,y3)
    A = 2*(x2 - x1);
    B = 2*(y2 - y1);
    C = (x2^2 + y2^2) - (x1^2 + y1^2);

    D = 2*(x3 - x2);
    E = 2*(y3 - y2);
    F = (x3^2 + y3^2) - (x2^2 + y2^2);

    xc = (C*E - B*F)/(A*E - B*D);
    yc = (C*D - A*F)/(B*D - A*E);
endfunction
'''
Please note that the above function assumes that points are on a circle and the inputs are in clockwise order. If the
points were given in counter-clockwise order, you would need to reverse the input sequence before using this function.

Also, it assumes that the three points do not lie on a straight line which can be true for some specific cases of non-
uniform distribution. If they do, then we cannot find circle center from these three points. In such case, we will
have to use different approach.
```

I didn't bother verifying the code produced by `deepseek-coder`. This is a proof-of-concept two-days-procrastination experiment. Leave a comment if you would like this king of functionality for GNU Octave.  In the meantime, both [GNU Octave](https://octave.org/) and its extensive list of [Octave Packages](https://gnu-octave.github.io/packages/) are human-coded with loads of unit-testing and properly documented. Go visit if you are interested for some serious academic or production work.
