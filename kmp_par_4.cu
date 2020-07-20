#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "timerc.h"

//Author: Dario Loriato
//Apologies for the multiple print statements within the functions, there was a lot of testing to be done


__global__ void alg(char* text_string, char* word, int word_len, int pat_len, int wrd_tbl[], int ans[]){
	int ix=blockIdx.x*blockDim.x+threadIdx.x;
	int pos=ix*128;
        int j=0;
	
	//TESTING THE PARALLEL ALG
	//printf("Thread ID: %d\n",ix);
	//printf("This is the word: %s\n", word);
	//printf("Word len: %d, Pat len: %d\n", word_len, pat_len);
	//printf("This is the word table: ");
	//for(int i=0;i<word_len;i++){
	//	printf("%d",wrd_tbl[i]);
	//}
	//printf("\n");
	//printf("Printing out the characters for text_string: ");
	//for(int i=0;i<10;i++){
	//	printf("<%c>", text_string[i]);
	//}
	//printf("\n");

	for(int i=0;i<128;i++){
		//printf("Index is: %d, Char is: %c\n", pos, text_string[pos]);
		if(text_string[pos]==word[j+1]){
			j++;
			//printf("Char in text: %c Matches with char: %c WrdTbl value is: %d Index is: %d \n", text_string[pos], word[j+1],j,i);
		}else{
			j=wrd_tbl[j];
		}
		if((j+1)==word_len){
			//printf("Pattern match found at position %d \n", (pos-(word_len-2)));
			ans[pos-(word_len-2)]=1;
			j=0;
		}
		ans[pos]=0;
		pos++;
	}
	if(j>0){
		ans[pos-j]=2;
	}
}

void serial_alg(char* text_string, char* word, int word_len, int pat_len, int wrd_tbl[]){
	int j=0;
	for(int i=0;i<pat_len;i++){
		if(text_string[i]==word[j+1]){
			j++;
		}else{
			j=wrd_tbl[j];
		}
		if((j+1)==word_len){
			printf("Pattern match found at position %d\n", (i-(word_len-2)));
		}
	}
}

void tableBuild(char* word, int wrd_tbl[]){
	int k = strlen(word);
	//printf("Length of string %d\n",k);
	int match;
	for(int i=1;i<(k-1);i++){
		if(wrd_tbl[i]==0){
			match=i+1;
			while(match<k){
				if(word[i]==word[match]){
					//printf("i is: %d, match is: %d, word[i] is: %c, word[match] is: %c \n", i, match, word[i], word[match]);
					wrd_tbl[match]=i;
				}
				match++;
			}
		}
	}
}

int main(int argc, char*argv[]){

	//GET THE WORD
	FILE * file_w =fopen("pattern.txt","r");
	fseek(file_w, 0L, SEEK_END);
	int word_len =ftell(file_w);
	rewind(file_w);
	char* word =(char*)malloc(word_len*sizeof(char));
	fgets(word, word_len, file_w);
	fclose(file_w);
	word_len=strlen(word);
	//printf("testing read: %c\n",word[0]);

	//GET THE TEXT FILE
	FILE * file_s =fopen("text_string.txt","r");	
	fseek(file_s, 0L, SEEK_END);
	int pat_len=ftell(file_s);
	rewind(file_s);
	char* text_string =(char*)malloc(pat_len*sizeof(char));
	fgets(text_string, pat_len, file_s);
	fclose(file_s);
	pat_len=strlen(text_string);
	//printf("testing pat: %s\n", text_string);
	
	//CREATE THE K-TABLE
	int* wrd_tbl= new int[word_len];
	for(int i=0;i<word_len;i++){
		wrd_tbl[i]=0;
	}
	tableBuild(word, wrd_tbl);


	//CALCULATIONS FOR BLOCK AND THREAD NUMBERS
	int threadnumber=pat_len/128;
	if(pat_len%128!=0){
		threadnumber++;
	}
	int blocknumber=1;
	if(threadnumber>1024){
		blocknumber=(threadnumber/1024);
		if(threadnumber%1024!=0){
			blocknumber++;
		}
		threadnumber=1024;
	}

	//PRINT INFORMATION
	printf("Word to find: <%s> - is a placeholder\n",word);
	printf("Wordlen is:  %d, Patlen is: %d\n",word_len, pat_len);
        printf("Array for ktable: ");
        for(int i=0;i<word_len;i++){
                printf("%d ",wrd_tbl[i]);
        }
        printf("\n");
	printf("Thread count: %d, Block count: %d\n", threadnumber, blocknumber);


	//
	//CPU TEST
	//

	//START CPU TIMING
	float cpu_time;
	cstart();

	//RUN TEST
	serial_alg(text_string, word, word_len, pat_len, wrd_tbl);

	//END CPU TIMING
	cend(&cpu_time);
	printf("CPU Serial time: %f\n", cpu_time);


	//
	//GPU TEST
	//

	//CREATE ALL OF THE CUDA VARIABLES
	char* d_text_string;
	char* d_word;
	int* d_wrd_tbl;
	int* d_ans;

	cudaMalloc((void**)&d_text_string, pat_len*sizeof(char));
	cudaMalloc((void**)&d_word, word_len*sizeof(char));
	cudaMalloc((void**)&d_wrd_tbl, word_len*sizeof(int));
	cudaMalloc((void**)&d_ans, pat_len*sizeof(int));

	cudaMemcpy(d_text_string, text_string, pat_len*sizeof(char), cudaMemcpyHostToDevice);
	cudaMemcpy(d_word, word, word_len*sizeof(char), cudaMemcpyHostToDevice);
	cudaMemcpy(d_wrd_tbl, wrd_tbl, word_len*sizeof(int), cudaMemcpyHostToDevice);

	//START GPU TIMING
	float gpu_time;
	gstart();
	
	//CALL CUDA KERNEL
	alg<<<blocknumber, threadnumber>>>(d_text_string, d_word, word_len, pat_len, d_wrd_tbl, d_ans);
	//TEST
	//alg<<<1,1>>>(d_text_string, d_word, word_len, pat_len, d_wrd_tbl);

	//RETRIEVE AND OUTPUT ANSWERS
	int *ans=new int[pat_len];
	cudaMemcpy(ans, d_ans, pat_len*sizeof(int), cudaMemcpyDeviceToHost);
	for(int i=0;i<pat_len;i++){
		if(ans[i]==1){
			printf("Pattern match found at position %d\n", i);
		}
		if(ans[i]==2){
			int ct=1, mtc=0;
			for(int j=i;j<i+(word_len-1);j++){
				if(text_string[j]==word[ct]){
					mtc++;
				}
				ct++;
			}
			if(mtc==(word_len-1)){
				printf("Pattern match found at position %d\n",i);
			}
		}

	}

	//END GPU TIMING
	gend(&gpu_time);
	printf("GPU Output time: %f\n", gpu_time);


	//FREE VARIABLES
	cudaFree(d_text_string);
	cudaFree(d_word);
	cudaFree(d_wrd_tbl);
	cudaFree(d_ans);
	free(text_string);
	free(word);
	free(wrd_tbl);
	free(ans);

	return 0;
}
