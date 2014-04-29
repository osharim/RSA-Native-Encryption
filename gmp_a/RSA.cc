// Implementation of the RSA public-key encryption algorithm
// ECE4893/ECE8893, Fall 2012
//Phillip Johnston
//24 October 2012

#include <stdint.h>
#include <iostream>
#include <cstdlib>
#include <time.h>
#include <cmath>
#import "gmp.h"
#import "gmpxx.h"

//#include "gmp.h"

//#include "gmpxx.h"

using namespace std;

/*
 * RSA
 p,q are large primes
 n = p * q
 phi(n) = (p - 1) * (q - 1)
 choose random d of sz * 2, d < phi(n)
 
 ensure gcd of d and phi(n) is exactly 1.  If not, choose another
 
 e = multiplicative inverse of d mod phi(n)
 
 c = m^d mod n
 
 */

/*
 * Define Statements
 */
#define NUM_ITERATIONS 6
#define NUM_KEYS 100
#define NUM_MESSAGES 100

/*
 * Function definitions
 */
void init();
void initMpVars(unsigned long bit_size);
void clearMpVars();
void generateKeys(unsigned long bit_size);
void pickPrimes(mpz_t * P, mpz_t * Q, unsigned long bit_size);
void calculatePhi(mpz_t P, mpz_t Q, mpz_t * Phi);
void calculateD(mpz_t Phi, mpz_t * D, unsigned long bit_size);
void calculateE(mpz_t Phi, mpz_t D, mpz_t * E, unsigned long bit_size);
void generateMessage(mpz_t * msg, mpz_t N, unsigned long bit_size);
void encryptMessage(mpz_t * encrypted, mpz_t msg, mpz_t N, mpz_t D);
void decryptMessage(mpz_t * decrypted, mpz_t encrypted, mpz_t N, mpz_t E);
void verifyFidelity(mpz_t input, mpz_t output);

/*
 * Variables
 */
mpz_t p_arr[NUM_KEYS];
mpz_t q_arr[NUM_KEYS];
mpz_t n_arr[NUM_KEYS];
mpz_t phi_arr[NUM_KEYS];
mpz_t d_arr[NUM_KEYS];
mpz_t e_arr[NUM_KEYS];
unsigned long sizes_arr[NUM_ITERATIONS];
gmp_randstate_t randstate;



int main()
{
	init();
    
	mpz_t msg_in, msg_encr, msg_out;
	mpz_init(msg_in);
	mpz_init(msg_encr);
	mpz_init(msg_out);
    
	for(int i = 0; i < NUM_ITERATIONS; i++)
	{
		cout << "Generating keys of size " << sizes_arr[i] << " bits." << endl;
		initMpVars(sizes_arr[i]);
        
		generateKeys(sizes_arr[i]);
        
		cout << "Generating messages and attempting encrypt/decrypt" << endl;
		for(int j = 0; j < NUM_MESSAGES; j++)
		{
            
			generateMessage(&msg_in, n_arr[i], sizes_arr[i]);
			encryptMessage(&msg_encr, msg_in, n_arr[j], d_arr[j]); //Encrypt with pub pair
			decryptMessage(&msg_out, msg_encr, n_arr[j], e_arr[j]); //Decrypt with priv pair
			verifyFidelity(msg_in, msg_out);
		}
        
		clearMpVars();
	}
    
	cout << "Execution complete." << endl;
}


void init()
{
	gmp_randinit_default(randstate);
	gmp_randseed_ui(randstate, time(NULL));
    
	sizes_arr[0] = 32;
	for(int i = 1; i < NUM_ITERATIONS; i++)
	{
		sizes_arr[i] = 2 * sizes_arr[i - 1];
	}
}

void initMpVars(unsigned long bit_size)
{
	for(int i = 0; i < NUM_KEYS; i++)
	{
		mpz_t temp;
		mpz_init2(temp, bit_size);
        
		mpz_init2(p_arr[i], bit_size);
		//mpz_set_ui(p_arr[i], (unsigned long) floor(rand() % RAND_MAX));
		mpz_set_ui(p_arr[i], 2);
		mpz_pow_ui(temp, p_arr[i], bit_size/2);
		mpz_add_ui(p_arr[i], temp, gmp_urandomb_ui(randstate, bit_size/2));
		mpz_init2(q_arr[i], bit_size);
        
		//mpz_set_ui(q_arr[i], (unsigned long) floor(rand() % RAND_MAX));
		mpz_set_ui(q_arr[i], 2);
		mpz_pow_ui(temp, q_arr[i], bit_size/2);
		mpz_add_ui(q_arr[i], temp, gmp_urandomb_ui(randstate, bit_size/2));
        
		mpz_init2(n_arr[i], bit_size * 2);
		mpz_init2(phi_arr[i], bit_size * 2);
		mpz_init2(d_arr[i], bit_size * 2);
		mpz_init(e_arr[i]);
        
		mpz_clear(temp);
	}
}

void clearMpVars()
{
	for(int i = 0; i < NUM_KEYS; i++)
	{
		mpz_clear(p_arr[i]);
		mpz_clear(q_arr[i]);
		mpz_clear(n_arr[i]);
		mpz_clear(phi_arr[i]);
		mpz_clear(d_arr[i]);
		mpz_clear(e_arr[i]);
	}
}

void generateKeys(unsigned long bit_size)
{
    
	for(int i = 0; i < NUM_KEYS; i++)
	{
		//p, q are large primes
		pickPrimes(&p_arr[i], &q_arr[i], bit_size);
        
		//n = p * q
		mpz_mul(n_arr[i], p_arr[i], q_arr[i]);
        
		//phi(n) = (p - 1) * (q - 1)
		calculatePhi(p_arr[i], q_arr[i], &phi_arr[i]);
        
		calculateD(phi_arr[i], &d_arr[i], bit_size);
		calculateE(phi_arr[i], d_arr[i], &e_arr[i], bit_size);
        
	}
}

void pickPrimes(mpz_t * P, mpz_t * Q, unsigned long bit_size)
{
	mpz_t temp;
	mpz_init2(temp, bit_size);
    
	mpz_nextprime(temp, *P);
	mpz_set(*P, temp);
    
	do {
		mpz_nextprime(temp, *Q);
		mpz_set(*Q, temp);
	} while(mpz_cmp(*P, *Q) == 0); //Find the next prime until they're not equal?
}

void calculatePhi(mpz_t P, mpz_t Q, mpz_t * Phi)
{
	mpz_t p_1, q_1;
    
	mpz_init(p_1);
	mpz_init(q_1);
    
	//phi(n) = (p - 1) * (q - 1)
	mpz_sub_ui(p_1, P, 1);
	mpz_sub_ui(q_1, Q, 1);
	mpz_mul(*Phi, p_1, q_1);
    
	mpz_clear(p_1);
	mpz_clear(q_1);
}

void calculateD(mpz_t Phi, mpz_t * D, unsigned long bit_size)
{
	mpz_t temp;
	mpz_init2(temp, bit_size * 2);
    
	do
	{
		do
		{
			//choose random d of sz * 2, d < phi(n)
			mpz_set_ui(temp, gmp_urandomb_ui(randstate, bit_size));
            
			fflush(stdout);
            
		} while(mpz_cmp(Phi, temp) <= 0);
        
		mpz_set(*D, temp);
        
		//ensure gcd of d and phi(n) is exactly 1.  If not, choose another
		mpz_gcd(temp, *D, Phi);
	} while(mpz_cmp_ui(temp, 1) != 0);
    
	mpz_clear(temp);
}

void calculateE(mpz_t Phi, mpz_t D, mpz_t * E, unsigned long bit_size)
{
    
	//e = multiplicative inverse of d mod phi(n)
	mpz_invert(*E, D, Phi);
}

void generateMessage(mpz_t * msg, mpz_t N, unsigned long bit_size)
{
	mpz_set_ui(*msg, gmp_urandomb_ui(randstate, bit_size - 1));
}

void encryptMessage(mpz_t * encrypted, mpz_t msg, mpz_t N, mpz_t D)
{
	mpz_powm(*encrypted, msg, D, N);
}

void decryptMessage(mpz_t * decrypted, mpz_t encrypted, mpz_t N, mpz_t E)
{
	int root;
	mpz_t temp;
	mpz_init(temp);
    
	//take the temp'th root of encrypted
	mpz_powm(*decrypted, encrypted, E, N);
}


void verifyFidelity(mpz_t input, mpz_t output)
{
	if(mpz_cmp(input, output) == 0)
	{
		//cout << "Encryption/Decryption was a success!" << endl;	
	}
	else
	{
		cout << "Encryption/Decryption failure encountered!" << endl;
	}
    
}