import math
import base64




data = b"A" * 8 + b"B" * 8  + b"C" * 8 + b"D" * 8 + b"E" * 8 + b"F" * 8  + b"G" * 8 + b"H" * 8 + b"I" * 8 + b"J" * 8  + b"K" * 8 + b"L" * 8 + b"M" * 8 + b"N" * 8  + b"O" * 8 + b"P" * 8
#data="11111111000000001111111100000000111111110000000011111111000000001111111100000000111111110000000011111111000000001111111100000000"


#def AES_Top(key: str, data: str):



def dataToState(data:str):
    
    block = [data[i:i+8] for i in range(0, len(data), 8)]


    state = [
            [block[0],  block[4],  block[8],  block[12]],
            [block[1],  block[5],  block[9],  block[13]],
            [block[2],  block[6],  block[10], block[14]],
            [block[3],  block[7],  block[11], block[15]]
        ]
    return state



def displayState(state):
    for state in state:
        print(state)


displayState(dataToState(data))
              
"""""

def main(key:bytes,data:str):
    AES_Top()



if __name__ == "__main__":
    main(sys.argv[2])

"""""
