//
//  ViewController.m
//  gmp_a
//
//  Created by Omr on 25/04/14.
//  Copyright (c) 2014 Omr. All rights reserved.






#import "ViewController.h"
#import "GMPInt.h"
#include <stdio.h>

#include <sys/time.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include "gmp.h"

#define MODULUS_SIZE 1024                   /* This is the number of bits we want in the modulus */
#define BLOCK_SIZE (MODULUS_SIZE/8)         /* This is the size of a block that gets en/decrypted at once */
#define BUFFER_SIZE ((MODULUS_SIZE/8) / 2)  /* This is the number of bytes in n and p */

typedef struct {
    mpz_t n; /* Modulus */
    mpz_t e; /* Public Exponent */
} public_key;

typedef struct {
    mpz_t n; /* Modulus */
    mpz_t e; /* Public Exponent */
    mpz_t d; /* Private Exponent */
    mpz_t p; /* Starting prime p */
    mpz_t q; /* Starting prime q */
} private_key;



void print_hex(char* arr, int len)
{
    int i;
    for(i = 0; i < len; i++)
        printf("%02x", (unsigned char) arr[i]);
}



#define PUBFILE	"/Users/omr/Desktop/GMP\ Moviles/gmp_a/gmp_a/pubkey.rsa"
#define SECFILE "/Users/omr/Desktop/GMP\ Moviles/gmp_a/gmp_a/seckey.rsa"
volatile unsigned int i, counter, value;

static void handler(void);

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    GMPInt *myInteger = [[GMPInt alloc] initWithUnsignedLong:673];
    bool isPRime = [myInteger isPrime]; // should return true
    NSLog( isPRime  ? @"Yes" : @"No");
    
    [myInteger nextPrime];
    
    NSLog(@" next prime -> %@",myInteger );
    // will set value to 3
    
    // Perform 3^1000000
    [myInteger powerWithUnsignedLong:1000000];
    
    rsa_main();
    
 
	// Do any additional setup after loading the view, typically from a nib.
}


void block_encrypt(mpz_t C, mpz_t M, public_key kp)
{
    /* C = M^e mod n */
    mpz_powm(C, M, kp.e, kp.n);
    return;
}

void block_decrypt(mpz_t M, mpz_t C, private_key ku)
{
    mpz_powm(M, C, ku.d, ku.n);
    return;
}





/* NOTE: Assumes mpz_t's are initted in ku and kp */
void generate_keys(private_key* ku, public_key* kp)
{
    
    /**********************************************************************
     *                                                                    *
     * Created by Adam Brockett                                           *
     *                                                                    *
     * Copyright (c) 2010                                                 *
     *                                                                    *
     * Redistribution and use in source and binary forms, with or without *
     * modification is allowed.                                           *
     *                                                                    *
     * But if you let me know you're using my code, that would be freaking*
     * sweet.                                                             *
     *                                                                    *
     **********************************************************************/
    
    
    
    char buf[BUFFER_SIZE];
    int i;
    mpz_t phi; mpz_init(phi);
    mpz_t tmp1; mpz_init(tmp1);
    mpz_t tmp2; mpz_init(tmp2);
    
    NSLog(@"-------------- Calcule RSA --------------------------");
    srand(time(NULL));
    
    /* Insetead of selecting e st. gcd(phi, e) = 1; 1 < e < phi, lets choose e
     * first then pick p,q st. gcd(e, p-1) = gcd(e, q-1) = 1 */
    // We'll set e globally.  I've seen suggestions to use primes like 3, 17 or
    // 65537, as they make coming calculations faster.  Lets use 3.
    mpz_set_ui(ku->e, 3);
    
    /* Select p and q */
    /* Start with p */
    // Set the bits of tmp randomly
         NSLog(@"Select  p");
    for(i = 0; i < BUFFER_SIZE; i++)
        buf[i] = rand() % 0xFF;
    // Set the top two bits to 1 to ensure int(tmp) is relatively large
    buf[0] |= 0xC0;
    // Set the bottom bit to 1 to ensure int(tmp) is odd (better for finding primes)
    buf[BUFFER_SIZE - 1] |= 0x01;
    // Interpret this char buffer as an int
    mpz_import(tmp1, BUFFER_SIZE, 1, sizeof(buf[0]), 0, 0, buf);
    // Pick the next prime starting from that random number
    mpz_nextprime(ku->p, tmp1);
    /* Make sure this is a good choice*/
    NSLog(@"Make sure that..  p mod e == 1, gcd(phi, e) != 1  ");
    mpz_mod(tmp2, ku->p, ku->e);        /* If p mod e == 1, gcd(phi, e) != 1 */
    while(!mpz_cmp_ui(tmp2, 1))
    {
        mpz_nextprime(ku->p, ku->p);    /* so choose the next prime */
        mpz_mod(tmp2, ku->p, ku->e);
    }
    
    /* Now select q */
     NSLog(@"Select  q");
    do {
        for(i = 0; i < BUFFER_SIZE; i++)
            buf[i] = rand() % 0xFF;
        // Set the top two bits to 1 to ensure int(tmp) is relatively large
        buf[0] |= 0xC0;
        // Set the bottom bit to 1 to ensure int(tmp) is odd
        buf[BUFFER_SIZE - 1] |= 0x01;
        // Interpret this char buffer as an int
        mpz_import(tmp1, (BUFFER_SIZE), 1, sizeof(buf[0]), 0, 0, buf);
        // Pick the next prime starting from that random number
        mpz_nextprime(ku->q, tmp1);
        mpz_mod(tmp2, ku->q, ku->e);
        while(!mpz_cmp_ui(tmp2, 1))
        {
            mpz_nextprime(ku->q, ku->q);
            mpz_mod(tmp2, ku->q, ku->e);
        }
    } while(mpz_cmp(ku->p, ku->q) == 0); /* If we have identical primes (unlikely), try again */
    
    /* Calculate n = p x q */
      NSLog(@"Calculate  n = p x q");
    mpz_mul(ku->n, ku->p, ku->q);
    
    /* Compute phi(n) = (p-1)(q-1) */
       NSLog(@"Calculate   phi(n) = (p-1)(q-1)");
    mpz_sub_ui(tmp1, ku->p, 1);
    mpz_sub_ui(tmp2, ku->q, 1);
    mpz_mul(phi, tmp1, tmp2);
    
    /* Calculate d (multiplicative inverse of e mod phi) */
    NSLog(@"Calculate d (multiplicative inverse of e mod phi)");
    if(mpz_invert(ku->d, ku->e, phi) == 0)
    {
        mpz_gcd(tmp1, ku->e, phi);
        printf("gcd(e, phi) = [%s]\n", mpz_get_str(NULL, 16, tmp1));
        printf("Invert failed\n");
    }
    
    /* Set public key */
    NSLog(@"Set public key");
    mpz_set(kp->e, ku->e);
    mpz_set(kp->n, ku->n);
    
    return;
}







int rsa_main()
{
    int i;
    FILE *fp1, *fp2;
    mpz_t M;  mpz_init(M);
    mpz_t C;  mpz_init(C);
    mpz_t DC;  mpz_init(DC);
    private_key ku;
    public_key kp;
    
    // Initialize public key
    mpz_init(kp.n);
    mpz_init(kp.e);
    // Initialize private key
    mpz_init(ku.n);
    mpz_init(ku.e);
    mpz_init(ku.d);
    mpz_init(ku.p);
    mpz_init(ku.q);
    
//    fp2 = fopen(PUBFILE, "w");
//	if (fp2 == (FILE *) NULL)
//	{
//		perror(PUBFILE);
//		exit(-1);
//	}
//    fprintf(fp2, "_________ Private Key ____________");
//
//    fprintf(fp2, "n = %s\n", mpz_get_str(NULL, 16, kp.n));
//    fprintf(fp2, "e = %s\n", mpz_get_str(NULL, 16, kp.e));
//    fclose(fp2);
   
    
    generate_keys(&ku, &kp);
    printf("\n");
    printf("\n");
    printf("---------------Private Key-----------------");
  
    printf("kp.n is [%s]\n", mpz_get_str(NULL, 16, kp.n));
    printf("kp.e is [%s]\n", mpz_get_str(NULL, 16, kp.e));
 
    printf("---------------Public Key------------------");
    printf("ku.n --> Modulus  is [%s]\n", mpz_get_str(NULL, 16, ku.n));
    printf("ku.e --> Public Exponent is [%s]\n", mpz_get_str(NULL, 16, ku.e));
    printf("ku.d -->  [%s]\n", mpz_get_str(NULL, 16, ku.d));
    printf("ku.p -->  [%s]\n", mpz_get_str(NULL, 16, ku.p));
    printf("ku.q -->  [%s]\n", mpz_get_str(NULL, 16, ku.q));
     printf("\n");
     printf("\n");
    
    char buf[6*BLOCK_SIZE];
    for(i = 0; i < 6*BLOCK_SIZE; i++)
        buf[i] = rand() % 0xFF;
    
    
    mpz_import(M, (6*BLOCK_SIZE), 1, sizeof(buf[0]), 0, 0, buf);
    printf("original is [%s]\n", mpz_get_str(NULL, 16, M));
    printf("\n");
    block_encrypt(C, M, kp);
    printf("encrypted is [%s]\n", mpz_get_str(NULL, 16, C));
    printf("\n");
    block_decrypt(DC, C, ku);
    printf("decrypted is [%s]\n", mpz_get_str(NULL, 16, DC));
    return 0;
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
