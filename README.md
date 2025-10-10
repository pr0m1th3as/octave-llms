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

  ollama interface in 'query' mode connected at: http://localhost:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: default

    There are 4 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.
    Use 'loadModel' to set an active model for inference.
```
or remotelly
```
>> A = ollama ("http://192.168.5.18:11434")
A =

  ollama interface in 'query' mode connected at: http://192.168.5.18:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: default

    There are 2 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.
    Use 'loadModel' to set an active model for inference.
```
See available models with the `listModels` method.
```
>> listModels (A)
The following models are available in the ollama server:
  2x1 cell array

    {'llava:7b'     }
    {'gemma3:latest'}
```
If the [`datatypes`](https://github.com/pr0m1th3as/datatypes) package is available, you can also list available models in a table
```
>> listModels (A, 'table')
The following models are available in the ollama server:
  2x5 table

                       family       format     parameter    quantization       size
                     __________    ________    _________    ____________    ___________

    llava:7b         {'llama' }    {'gguf'}    {'7B'   }    {'Q4_0'    }    4.73336e+09
    gemma3:latest    {'gemma3'}    {'gguf'}    {'4.3B' }    {'Q4_K_M'  }     3.3388e+09
```
Set or remove custom options to be parsed to the model for inference.
```
>> setOptions (A, 'num_ctx', 8192)
>> A
A =

  ollama interface in 'query' mode connected at: http://192.168.5.18:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: custom

    There are 2 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.
    Use 'loadModel' to set an active model for inference.
>> setOptions (A, 'num_ctx', [])
>> A
A =

  ollama interface in 'query' mode connected at: http://192.168.5.18:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: default

    There are 2 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.
    Use 'loadModel' to set an active model for inference.
>>
```
If you need another model, you can ask your ollama server to download it directly from the Ollama library with:
```
>> pullModel (A, 'deepseek-coder:6.7b')
>> A
A =

  ollama interface in 'query' mode connected at: http://192.168.5.18:11434

              activeModel: ''
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: default

    There are 3 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.
    Use 'loadModel' to set an active model for inference.
>> listModels (A, 'table')
The following models are available in the ollama server:
  3x5 table

                             family       format     parameter    quantization       size
                           __________    ________    _________    ____________    ___________

    deepseek-coder:6.7b    {'llama' }    {'gguf'}    {'7B'   }    {'Q4_0'    }    3.82783e+09
    llava:7b               {'llama' }    {'gguf'}    {'7B'   }    {'Q4_0'    }    4.73336e+09
    gemma3:latest          {'gemma3'}    {'gguf'}    {'4.3B' }    {'Q4_K_M'  }     3.3388e+09
```
Set an active model before starting inference (either by name or by linear index) either by directly setting the parameter or with the `loadModel` method.
```
>> A.activeModel = 'deepseek-coder:6.7b'
A =

  ollama interface in 'query' mode connected at: http://192.168.5.18:11434

              activeModel: 'deepseek-coder:6.7b'
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: default

    There are 3 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.

>> loadModel (A, 1)
>> A
A =

  ollama interface in 'query' mode connected at: http://192.168.5.18:11434

              activeModel: 'deepseek-coder:6.7b'
              readTimeout: 300 (sec)
             writeTimeout: 300 (sec)
                  options: default

    There are 3 available models on this server.
    Use 'listModels' and 'listRunningModels' methods for more information.
```
Start inference in `query` mode:
```
>> txt = query (A, "Write a GNU Octave function to calculate the center of a circle from 3 points along its perimeter.")
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
**Note** that I didn't bother verifying the code produced by `deepseek-coder`. :)

Or choose another model
```
>> loadModel (A, 'llava:7b')
```
start a conversation in `chat` mode:
```
>> txt = chat (A, "Why is the sky blue?")
txt =  The sky appears blue because of the way light from the Sun interacts with Earth's atmosphere. When sunlight passes
through the atmosphere, it encounters molecules of gases such as nitrogen and oxygen. These molecules can scatter the
shorter-wavelength light, such as blues and violets, more than they scatter longer-wavelength light like reds and oranges.

As a result, blue light is scattered in all directions throughout the atmosphere, while the other colors travel straight
through. This scattering of blue light gives the sky its characteristic blue color. Additionally, the Earth's shadow cast
on the other side of the planet, known as the antipode, creates a darker region near the horizon, which appears to be a
deeper shade of blue orviolet.
>> chat (A, "Can you explain a bit more about about the relation of wavelength and scattering, please?")
ans =  Sure! The amount of scattering an object undergoes depends on its size compared to the wavelength of light it
interacts with. When an object is much smaller than the wavelength of light, the light will pass through the object without
being scattered.However, if the object is larger than the wavelength of light, the light will be scattered in various
directions.

In the case of Earth's atmosphere, the molecules of gases such as nitrogen and oxygen are much smaller than the wavelength
of visible light. Therefore, when sunlight passes through the atmosphere, it encounters these molecules and gets scattered
in all directions. This is known as elastic scattering, which means that the energy of the light is conserved during the
scattering process.

The shorter the wavelength of light (such as blues and violets), the more it will be scattered compared to longer-
wavelength light like reds and oranges. As a result, when we look up at the sky, we predominantly see blue light, which is
scattered in all directions throughout the atmosphere. The other colors are present too, but they are less intense due to
the scattering of shorter-wavelength light.

In summary, the color of the sky appears blue because the short-wavelength light (blues and violets) gets scattered more
than longer-wavelength light by molecules in Earth's atmosphere. This phenomenon is a result of the size of the objects
(in this case, atmospheric gases) compared to the wavelength of light they interact with.
```
At any point you can display the entire history of parts of it with the `showHistory` method:
```
>> showHistory (A)

 User:
 Why is the sky blue?

 Assistant:
  The sky appears blue because of the way light from the Sun interacts with Earth's atmosphere. When sunlight passes
through the atmosphere, it encounters molecules of gases such as nitrogen and oxygen. These molecules can scatter the
shorter-wavelength light, such as blues and violets, more than they scatter longer-wavelength light like reds and oranges.

As a result, blue light is scattered in all directions throughout the atmosphere, while the other colors travel straight
through. This scattering of blue light gives the sky its characteristic blue color. Additionally, the Earth's shadow cast
on the other side of the planet, known as the antipode, creates a darker region near the horizon, which appears to be a
deeper shade of blue orviolet.

 User:
 Can you explain a bit more about about the relation of wavelength and scattering, please?

 Assistant:
  Sure! The amount of scattering an object undergoes depends on its size compared to the wavelength of light it
interacts with. When an object is much smaller than the wavelength of light, the light will pass through the object without
being scattered.However, if the object is larger than the wavelength of light, the light will be scattered in various
directions.

In the case of Earth's atmosphere, the molecules of gases such as nitrogen and oxygen are much smaller than the wavelength
of visible light. Therefore, when sunlight passes through the atmosphere, it encounters these molecules and gets scattered
in all directions. This is known as elastic scattering, which means that the energy of the light is conserved during the
scattering process.

The shorter the wavelength of light (such as blues and violets), the more it will be scattered compared to longer-
wavelength light like reds and oranges. As a result, when we look up at the sky, we predominantly see blue light, which is
scattered in all directions throughout the atmosphere. The other colors are present too, but they are less intense due to
the scattering of shorter-wavelength light.

In summary, the color of the sky appears blue because the short-wavelength light (blues and violets) gets scattered more
than longer-wavelength light by molecules in Earth's atmosphere. This phenomenon is a result of the size of the objects
(in this case, atmospheric gases) compared to the wavelength of light they interact with.
```
or clear the chat history and start over
```
>> clearHistory (A)
>> showHistory (A)
No chat history to show. Start a chat first.
```
This is a proof-of-concept side project. Leave a comment if you would like this kind of functionality for GNU Octave.  In the meantime, both [GNU Octave](https://octave.org/) and its extensive list of [Octave Packages](https://gnu-octave.github.io/packages/) are human-coded with loads of unit-testing and properly documented. Go visit if you are interested for some serious academic or production work.
